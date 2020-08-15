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

    local FQDN
    FQDN="$(/bin/hostname --fqdn)"
    LDAP_URL="lda://$FQDN:$LDAP_PORT"
}

init_ldaps_url() {
    test -n "${LDAPS_URL}" && return

    local FQDN
    FQDN="$(/bin/hostname --fqdn)"
    LDAPS_URL="ldaps://$FQDN:$LDAPS_PORT"
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

# Reduce maximum number of number of open file descriptors
# see https://github.com/docker/docker/issues/8231
ulimit -n "$LDAP_NOFILE"

setup_timezone
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
