#!/bin/bash

DEBUG=${DEBUG:-"0"}

[ "${DEBUG}" -eq "1" ] && set -x

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

setup_dkim() {
    echo "Configuring OpenDKIM:"
    mkdir -p /run/opendkim
    chown -R opendkim:opendkim /run/opendkim
    sed -i -e 's|^Socket.*|Socket inet:8891@0.0.0.0|g' /etc/opendkim/opendkim.conf
    echo > /etc/opendkim/TrustedHosts
    echo > /etc/opendkim/KeyTable
    echo > /etc/opendkim/SigningTable
    echo "127.0.0.1" >> /etc/opendkim/TrustedHosts
    echo "::1" >> /etc/opendkim/TrustedHosts
    echo "localhost" >> /etc/opendkim/TrustedHosts
    for h in ${DKIM_TRUSTEDHOSTS}; do
        echo "${h}" >> /etc/opendkim/TrustedHosts
    done

    mkdir -p /etc/opendkim/keys
    for d in $DKIM_DOMAINS; do
	domain=$(echo "$d"| cut -f1 -d '=')
	selector=$(expr match "$d" '.*\=\(.*\)')
	if [ -z "$selector" ] ; then
	    selector="mail"
	fi
	domain_dir=/etc/opendkim/keys/${domain}
	private_key=${domain_dir}/${selector}.private
	if [ -f "${private_key}" ]; then
	    echo "- ${domain} (selector:${selector})"
	    echo "${selector}._domainkey.${domain} ${domain}:${selector}:${private_key}" >> /etc/opendkim/KeyTable
	    echo "*@${domain} ${selector}._domainkey.${domain}" >> /etc/opendkim/SigningTable
	else
	    if [ "${DKIM_AUTOGENERATE}" -eq 1 ]; then
		echo "- ${domain}: auto generating key"
		mkdir -p "${domain_dir}"
		opendkim-genkey -b 2048 -h rsa-sha256 -r -v --subdomains -s ${selector} -D "${domain_dir}" -d "${domain}"
		echo "New DKIM keys have been generated! Please make sure to update your DNS records! You need to add the following details:"
		echo "====== ${private_key} ======"
		cat "${private_key}"
		echo
	    else
		echo "ERROR: Skipping DKIM for domain \"${domain}\". File \"${private_key}\" not found!"
	    fi
	fi
    done
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

stop_opendkim() {

    terminate opendkim
    terminate /sbin/syslogd
}

init_trap() {
    trap stop_opendkim TERM INT
}

#
# Main
#

# if command starts with an option, prepend opendkim default command
if [ "${1:0:1}" = '-' ]; then
        set -- opendkim -f -l -x /etc/opendkim/opendkim.conf "$@"
fi

init_trap
setup_timezone


# Configure and run dkim only if we have domains
if [ -n "$DKIM_DOMAINS" ]; then
    setup_dkim
fi

if [ "$1" = 'opendkim' ]; then
    # Don't start syslogd in background while starting it in the background...
    # Logging to stdout does not work else.
    /sbin/syslogd -n -S -O - &
    if [ -d /etc/opendkim/keys -a -n "$(find /etc/opendkim/keys -type f ! -name .)" ]; then
	echo "Starting opendkim..."
	"$@"
    else
	echo "No domain keys found..."
	exit 1
    fi
else
    exec "$@"
fi
