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

if [ "$1" = '/usr/sbin/slapd' ]; then
    if [ ! -d $SLAPD_PID_DIR ]; then
	mkdir -p $SLAPD_PID_DIR
	chown ldap:ldap $SLAPD_PID_DIR
    fi
    echo -n "Starting OpenLDAP server"
    exec /usr/sbin/slapd  -h "$LDAP_URLS $LDAPS_URLS $LDAPI_URLS" \
         $SLAPD_CONFIG_ARG $USER_CMD $GROUP_CMD \
         $OPENLDAP_SLAPD_PARAMS $SLAPD_SLP_REG
else
    exec "$@"
fi
