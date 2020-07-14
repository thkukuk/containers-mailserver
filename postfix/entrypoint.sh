#!/bin/bash

[ "${DEBUG}" = "yes" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}

setup_timezone() {
    if [ -n "$TZ" ]; then
	TZ_FILE="/usr/share/zoneinfo/$TZ"
	if [ -f "$TZ_FILE" ]; then
	    echo "Setting container timezone to: $TZ"
	    ln -snf "$TZ_FILE" /etc/localtime
	else
	    echo "Cannot set timezone \"$TZ\": timezone does not exist."
	fi
    fi
}

set_config_value() {
    key=${1}
    value=${2}

    echo "Setting configuration option \"${key}\" with value \"${value}\""
    postconf -e "${key} = ${value}"
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'SMTP_PASSWORD' 'example'
# (will allow for "$SMTP_PASSWORD_FILE" to fill in the value of
#  "$SMTP_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
    var="$1"
    fileVar="${var}_FILE"
    def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

update_db() {
    while test "x$1" != "x" ; do
        pfmap=/etc/postfix/${1}
        test -e "${pfmap}" && \
            if test "${pfmap}" -nt "${pfmap}.db" -o ! -e "${pfmap}.db" ; then
		echo "rebuilding ${pfmap}.db"
		postmap "${pfmap}"
            fi
        shift
    done
}

configure_aliases() {

    get_alias_maps() {
	test -d /etc/aliases.d && test "$(echo /etc/aliases.d/*)" != "/etc/aliases.d/*" && \
            for i in $(find /etc/aliases.d -maxdepth 1 -type f \
			    '!' -regex ".*\.\(db\|rpmsave\|rpmorig\)" \
			    '!' -regex ".*/\(\.\|#\).*" \
			    '!' -regex ".*~$") ; do
		echo -n "$i ";
	    done
    }

    echo "Building /etc/aliases.db."
    /usr/bin/newaliases

    ALLMAPS="hash:/etc/aliases"
    for i in $(get_alias_maps); do
        ALLMAPS="${ALLMAPS}, hash:$i"
	echo "Building $i.db"
	postalias "${i}"
    done
    set_config_value "alias_maps" "${ALLMAPS}"
}

configure_postfix() {

    if [ -n "${INET_PROTOCOLS}" ]; then
	set_config_value "inet_protocols" "{$INET_PROTOCOLS}"
    else
	# XXX Containers have ipv6 addresses, but not routeable
	#if ip addr show dev lo | grep -q inet6 ; then
	#    set_config_value "inet_protocols" "all"
	#else
	     set_config_value "inet_protocols" "ipv4"
	#fi
    fi

    # Always allow private networks, we are running in a container...
    networks='127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16'
    if [ -n "${SMTP_NETWORKS}" ]; then
	networks+=", ${SMTP_NETWORKS}"
    fi
    set_config_value "mynetworks" "${networks}"

    if [ -n "${SERVER_HOSTNAME}" ]; then
	if [ -z "${SERVER_DOMAIN}" ]; then
	    SERVER_DOMAIN=$(echo "${SERVER_HOSTNAME}" | cut -d"." -f2-)
	fi
	set_config_value "myhostname" "${SERVER_HOSTNAME}"
	set_config_value "mydomain" "${SERVER_DOMAIN}"
    fi

    if [ -n "${MYDESTINATION}" ]; then
	set_config_value "mydestination" "${MYDESTINATION}"
    fi

    if [ -n "${SMTP_RELAYHOST}" ]; then
        SMTP_PORT="${SMTP_PORT:-587}"
    	set_config_value "relayhost" "${SMTP_RELAYHOST}:${SMTP_PORT}"
    	set_config_value "smtp_use_tls" "yes"
    	# XXX enforce tls, not sure if this is always a good idea
	set_config_value "smtp_enforce_tls" "yes"
	set_config_value "smtp_tls_CApath" "/etc/postfix/ssl/cacerts"
	# Debug only:
	# set_config_value "smtp_tls_loglevel" "2"
    fi

    if [ -n "${SMTP_USERNAME}" ]; then
	file_env 'SMTP_PASSWORD'
	if [ -z "${SMTP_PASSWORD}" ]; then
	    echo "SMTP_PASSWORD is not set"
	    exit 1
	fi
	# Add auth credentials to sasl_passwd
	echo "Adding SASL authentication configuration"
	echo "${SMTP_RELAYHOST} ${SMTP_USERNAME}:${SMTP_PASSWORD}" >> /etc/postfix/sasl_passwd
	update_db sasl_passwd
	set_config_value "smtp_sasl_password_maps" "hash:/etc/postfix/sasl_passwd"
	set_config_value "smtp_sasl_auth_enable" "yes"
	set_config_value "smtp_sasl_security_options" "noanonymous"
    fi

    if [ -n "${MASQUERADE_DOMAINS}" ]; then
        set_config_value "masquerade_domains" "${MASQUERADE_DOMAINS}"
    fi

    # Add maps to config and create database
    for i in canonical relocated sender_canonical transport virtual; do
	set_config_value "${i}_maps" "hash:/etc/postfix/${i}"
	update_db "${i}"
    done
    set_config_value "smtpd_sender_restrictions" "hash:/etc/postfix/access"
    # Generate and update maps
    update_db access relay
}

terminate() {
    base=$(basename "$1")
    pid=$(/bin/pidof "$base")

    if [ -n "$pid" ]; then
	echo "Terminating $base..."
	if kill "$pid" ; then
	    echo "Terminating $base failed!"
	fi
    else
	echo "Failure determining PID of $base"
    fi
}

init_trap() {
    trap stop_postfix TERM INT
}

stop_postfix() {

    typeset -i sec=$1
    typeset -i ms=$((sec*100))

    (   while ! pidof qmgr > /dev/null 2>&1 ; do
            ((ms-- <= 0)) && break
            usleep 10000
	done
	exec postfix flush
    ) > /dev/null 2>&1 &

    postfix stop
    terminate /sbin/syslogd
}

start_postfix() {
    # Don't start syslogd in background while starting it in the background...
    # Logging to stdout does not work else.
    /sbin/syslogd -n -S -O - &
    "$@"
}

#
# Main
#

# if command starts with an option, prepend postfix
if [ "${1:0:1}" = '-' ]; then
        set -- postfix start "$@"
fi

init_trap
setup_timezone
# configure postfix even if postfix will not be started, to
# allow to see the result with postconf for debugging/testing.
configure_postfix
configure_aliases

# If host mounting /var/spool/postfix, we need to delete the old pid file
# before starting services
rm -f /var/spool/postfix/pid/master.pid

if [ "$1" = 'postfix' ]; then
    start_postfix "$@"
    echo "postfix running and ready"
    /usr/bin/pause
else
    exec "$@"
fi
