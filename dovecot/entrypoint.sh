#!/bin/bash

[ "${DEBUG}" = "1" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}

DOVECOT_RUN_DIR=${DOVECOT_RUN_DIR:-"/run/dovecot"}

# Default values for new database
DOVECOT_ORGANIZATION=${DOVECOT_ORGANIZATION:-"Example Inc."}
DOVECOT_DOMAIN=${DOVECOT_DOMAIN:-"example.org"}
DOVECOT_BASE_DN=${DOVECOT_BASE_DN:-""}

# TLS
DOVECOT_TLS=${DOVECOT_TLS:-"1"}
DOVECOT_TLS_CA_CRT=${DOVECOT_TLS_CA_CRT:-"/etc/dovecot/certs/dovecot-ca.crt"}
DOVECOT_TLS_CA_KEY=${DOVECOT_TLS_CA_KEY:-"/etc/dovecot/certs/dovecot-ca.key"}
DOVECOT_TLS_CRT=${DOVECOT_TLS_CRT:-"/etc/dovecot/certs/tls.crt"}
DOVECOT_TLS_KEY=${DOVECOT_TLS_KEY:-"/etc/dovecot/certs/tls.key"}
DOVECOT_TLS_DH_PARAM=${DOVECOT_TLS_DH_PARAM:-"/etc/dovecot/certs/dhparam.pem"}

DOVECOT_TLS_ENFORCE=${DOVECOT_TLS_ENFORCE:-"0"}
DOVECOT_TLS_CIPHER_SUITE=${DOVECOT_TLS_CIPHER_SUITE:-"ECDHE-RSA-CHACHA20-POLY1305:HIGH:-VERS-TLS-ALL:+VERS-TLS1.2:+VERS-TLS1.3:!SSLv3:!SSLv2:!ADH"}
DOVECOT_TLS_VERIFY_CLIENT=${DOVECOT_TLS_VERIFY_CLIENT:-demand}

VMAIL_UID="${VMAIL_UID:-5000}"

# LDAP
USE_LDAP=${USE_LDAP:-"0"}
LDAP_SERVER_URL=${LDAP_SERVER_URL:-"ldap://localhost"}
LDAP_DN_READER=${LDAP_DN_READER:-"cn=mailAccountReader,ou=Manager,dc=example,dc=org"}
LDAP_DNPASS_READER_FILE=${LDAP_DNPASS_READER_FILE:-"/etc/dovecot-secrets/LDAP_DNPASS_READER_FILE"}
LDAP_USE_TLS=${LDAP_USE_TLS:-"1"}
LDAP_TLS_CA_CRT=${LDAP_TLS_CA_CRT:-"/etc/openldap/certs/openldap-ca.crt"}

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

setup_vmail_user() {
    # Create the vmail user with the requested UID
    if [ -x /usr/sbin/adduser ]; then
        adduser -D -h /var/spool/vmail -g "Virtual Mail User" -u "${VMAIL_UID}" -s /sbin/nologin vmail
    else
        useradd -d /var/spool/vmail -U -c "Virtual Mail User" -u "${VMAIL_UID}" vmail
    fi
    if [ $? -ne 0 ]; then
        echo "ERROR: creating of vmail user failed! Aborting."
        exit 1
    fi

    if [ ! -d /var/spool/vmail ]; then
        mkdir -p /var/spool/vmail
        chown vmail:vmail /var/spool/vmail
        chmod 775 /var/spool/vmail
    fi
}

setup_default_config() {

    mkdir -p "${DOVECOT_RUN_DIR}"

    [ -z "$(ls -A /etc/dovecot)" ] || return

    # Only continue
    cp -a /usr/share/dovecot/example-config/* /etc/dovecot/

    sed -i -e 's|#log_path =.*|log_path = /dev/stderr|g' /etc/dovecot/conf.d/10-logging.conf

    if [ "${DEBUG}" = "1" ]; then
	# Enable some debug informations in conf.d/10-logging.conf
	sed -i -e 's|^#auth_verbose =.*|auth_verbose = yes|g' /etc/dovecot/conf.d/10-logging.conf
	sed -i -e 's|^#mail_debug =.*|mail_debug = yes|g' /etc/dovecot/conf.d/10-logging.conf
	sed -i -e 's|^#verbose_ssl =.*|verbose_ssl = yes|g' /etc/dovecot/conf.d/10-logging.conf
    fi

    # Where to find the mailfolders
    sed -i -e 's|^#mail_location =.*|mail_location = maildir:/var/spool/vmail/%d/%n|g' /etc/dovecot/conf.d/10-mail.conf

    # Enforce TLS
    sed -i -e 's|^#ssl =.*|ssl = required|g' /etc/dovecot/conf.d/10-ssl.conf
    sed -i -e "s|^ssl_cipher_list =.*|ssl_cipher_list = ${DOVECOT_TLS_CIPHER_SUITE}|" /etc/dovecot/conf.d/10-ssl.conf
    sed -i -e 's|^ssl_prefer_server_ciphers =.*|ssl_prefer_server_ciphers = yes|g' /etc/dovecot/conf.d/10-ssl.conf

    cat << 'EOT' >> /etc/dovecot/conf.d/10-master.conf
service imap-login {
    inet_listener imap {
        port = 143
        ssl = yes
    }
    inet_listener imaps {
        port = 993
        ssl = yes
    }

    service_count = 1
    process_min_avail = 1
}
EOT
}

setup_ldap() {
    [ ${USE_LDAP} = "1" ] || return

    # Disable enabled auth includes and add ldap
    sed -i -e 's|^!include\(.*\)|#!include\1|g' /etc/dovecot/conf.d/10-auth.conf
    echo "!include auth-ldap.conf.ext" >> /etc/dovecot/conf.d/10-auth.conf

    sed -i "s|#dn =.*|dn = ${LDAP_DN_READER}" /etc/dovecot/dovecot-ldap.conf.ext
    file_env LDAP_DNPASS_READER
    sed -i "s|#dnpass =.*|dnpass = ${LDAP_DNPASS_READER}" /etc/dovecot/dovecot-ldap.conf.ext
    if [ "${LDAP_USE_TLS}" = "1" ]; then
	echo "XXX"
    fi
}

# if command starts with an option, prepend dovecot
if [ "${1:0:1}" = '-' ]; then
        set -- /usr/sbin/dovecot "$@"
fi

# Generic setup
setup_timezone
setup_vmail_user
setup_default_config
echo "Updating certificate store..."
update-ca-certificates

exec "$@"
