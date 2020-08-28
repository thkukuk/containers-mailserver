#!/bin/bash

[ "${DEBUG}" = "1" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}

DOVECOT_RUN_DIR=${SLAPD_RUN_DIR:-"/run/dovecot"}

# Default values for new database
DOVECOT_ORGANISATION=${DOVECOT_ORGANISATION:-"Example Inc."}
DOVECOT_DOMAIN=${DOVECOT_DOMAIN:-"example.org"}
DOVECOT_BASE_DN=${DOVECOT_BASE_DN:-""}

# TLS
DOVECOT_TLS=${DOVECOT_TLS:-"1"}
DOVECOT_TLS_CA_CRT=${DOVECOT_TLS_CA_CRT:-"/etc/dovecot/certs/ca.crt"}
DOVECOT_TLS_CA_KEY=${DOVECOT_TLS_CA_KEA:-"/etc/dovecot/certs/ca.key"}
DOVECOT_TLS_CRT=${DOVECOT_TLS_CRT:-"/etc/dovecot/certs/tls.crt"}
DOVECOT_TLS_KEY=${DOVECOT_TLS_KEY:-"/etc/dovecot/certs/tls.key"}
DOVECOT_TLS_DH_PARAM=${DOVECOT_TLS_DH_PARAM:-"/etc/dovecot/certs/dhparam.pem"}

DOVECOT_TLS_ENFORCE=${DOVECOT_TLS_ENFORCE:-"0"}
DOVECOT_TLS_CIPHER_SUITE=${DOVECOT_TLS_CIPHER_SUITE:-"HIGH:-VERS-TLS-ALL:+VERS-TLS1.2:+VERS-TLS1.3:!SSLv3:!SSLv2:!ADH"}
DOVECOT_TLS_VERIFY_CLIENT=${DOVECOT_TLS_VERIFY_CLIENT:-demand}


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

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'DOVECOT_ADMIN_PASSWORD' 'example'
# (will allow for "$DOVECOT_ADMIN_PASSWORD_FILE" to fill in the value of
#  "$DOVECOT_ADMIN_PASSWORD" from a file, especially for Docker's secrets feature)
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

setup_default_config() {
    [ "$(ls -A /etc/dovecot)" ] || cp -a /entrypoint/default-config/* /etc/dovecot/
}

# if command starts with an option, prepend dovecot
if [ "${1:0:1}" = '-' ]; then
        set -- /usr/sbin/dovecot "$@"
fi

# Generic setup
setup_default_config
setup_timezone
echo "Updating certificate store..."
update-ca-certificates

exec "$@"
