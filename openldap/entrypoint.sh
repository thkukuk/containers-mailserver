#!/bin/bash

[ "${DEBUG}" = "yes" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}

LDAP_NOFILE=${LDAP_NOFILE:-1024}
LDAP_PORT=${LDAP_PORT:-389}
LDAPS_PORT=${LDAPS_PORT:-636}
LDAPI_URL=${LDAPI_URL:-"ldapi:///"}
#SLAPD_CONFIG_ARG="-F /etc/openldap/slapd.d"
SLAPD_LOG_LEVEL=${SLAPD_LOG_LEVEL:-1}
SLAPD_RUN_DIR=${SLAPD_RUN_DIR:-"/run/slapd"}
SLAPD_SLP_REG=${SLAPD_SLP_REG:-"-o slp=off"}

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

init_ldap_url() {
    test -n "${LDAP_URL}" && return


    if [ -n "${OPENLDAP_START_LDAP}" ]; then
	case "$OPENLDAP_START_LDAP" in
            [Yy][Ee][Ss])
		if [ -n "$OPENLDAP_LDAP_INTERFACES" ]
		then
                    for iface in $OPENLDAP_LDAP_INTERFACES ;do
			LDAP_URL="$LDAP_URL ldap://$iface"
                    done
		else
                    LDAP_URL="ldap:///"
		fi
		;;
	esac
    else
	local FQDN
	FQDN="$(/bin/hostname -f)"
	LDAP_URL="ldap://$FQDN:$LDAP_PORT"
    fi
}

init_ldaps_url() {
    test -n "${LDAPS_URL}" && return

    if [ -n "${OPENLDAP_START_LDAPS}" ]; then
	case "$OPENLDAP_START_LDAPS" in
            [Yy][Ee][Ss])
		if [ -n "$OPENLDAP_LDAP_INTERFACES" ]
		then
                    for iface in $OPENLDAP_LDAPS_INTERFACES ;do
			LDAPS_URL="$LDAPS_URL ldaps://$iface"
                    done
		else
                    LDAPS_URL="ldaps:///"
		fi
		;;
	esac
    else
	local FQDN
	FQDN="$(/bin/hostname -f)"
	LDAPS_URL="ldaps://$FQDN:$LDAPS_PORT"
    fi
}

setup_ldap_uidgid() {
    CUR_LDAP_UID=$(id -u ldap)
    CUR_LDAP_GID=$(id -g ldap)

    LDAP_UIDGID_CHANGED=false
    if [ "$LDAP_UID" != "$CUR_LDAP_UID" ]; then
	echo "Current ldap UID (${CUR_LDAP_UID}) does not match LDAP_UID (${LDAP_UID}), adjusting..."
	usermod -o -u "$LDAP_UID" ldap
	LDAP_UIDGID_CHANGED=true
    fi
    if [ "$LDAP_GID" != "$CUR_USER_GID" ]; then
	echo "Current ldap GID (${CUR_LDAP_GID}) does't match LDAP_GID (${LDAP_GID}), adjusting..."
	groupmod -o -g "$LDAP_GID" ldap
	LDAP_UIDGID_CHANGED=true
    fi

    echo 'OpenLDAP GID/UID'
    echo "User uid:    $(id -u openldap)"
    echo "User gid:    $(id -g openldap)"
    echo "uid/gid changed: ${LDAP_UIDGID_CHANGED}"
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'LDAP_ADMIN_PASSWORD' 'example'
# (will allow for "$LDAP_ADMIN_PASSWORD_FILE" to fill in the value of
#  "$LDAP_ADMIN_PASSWORD" from a file, especially for Docker's secrets feature)
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

# if command starts with an option, prepend postfix
if [ "${1:0:1}" = '-' ]; then
        set -- /usr/sbin/slapd "$@"
fi

test -f /etc/sysconfig/openldap && . /etc/sysconfig/openldap

# Reduce maximum number of number of open file descriptors
# see https://github.com/docker/docker/issues/8231
ulimit -n "$LDAP_NOFILE"

setup_timezone
setup_ldap_uidgid
init_ldap_url
init_ldaps_url

if [ "$1" = '/usr/sbin/slapd' ]; then
    if [ ! -d "$SLAPD_RUN_DIR" ]; then
	mkdir -p "$SLAPD_RUN_DIR"
	chown ldap:ldap "$SLAPD_RUN_DIR"
    fi
    echo "Starting OpenLDAP server"
    exec /usr/sbin/slapd -d ${SLAPD_LOG_LEVEL} \
	 -h "$LDAP_URL $LDAPS_URL $LDAPI_URL" \
         $SLAPD_CONFIG_ARG $USER_CMD $GROUP_CMD \
         $OPENLDAP_SLAPD_PARAMS $SLAPD_SLP_REG
else
    exec "$@"
fi
