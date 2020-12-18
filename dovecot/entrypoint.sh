#!/bin/bash

DEBUG=${DEBUG:-"0"}

[ "${DEBUG}" = "1" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}

DOVECOT_RUN_DIR=${DOVECOT_RUN_DIR:-"/run/dovecot"}
DOVECOT_CERTS_DIR=${DOVECOT_CERTS_DIR:-"/etc/certs"}

# Generic values
USE_VMAIL_USER=${USE_VMAIL_USER:-"1"}
VMAIL_UID=${VMAIL_UID:-"5000"}
ENABLE_IMAP=${ENABLE_IMAP:-"1"}
ENABLE_POP3=${ENABLE_POP3:-"0"}
ENABLE_LMTP=${ENABLE_LMTP:-"0"}
ENABLE_SIEVE=${ENABLE_SIEVE:-"1"}
ENABLE_MANAGESIEVE=${ENABLE_MANAGESIEVE:-"0"}

# TLS
DOVECOT_TLS=${DOVECOT_TLS:-"1"}
DOVECOT_TLS_CA_CRT=${DOVECOT_TLS_CA_CRT:-"${DOVECOT_CERTS_DIR}/dovecot-ca.crt"}
DOVECOT_TLS_CA_KEY=${DOVECOT_TLS_CA_KEY:-"${DOVECOT_CERTS_DIR}/dovecot-ca.key"}
DOVECOT_TLS_CRT=${DOVECOT_TLS_CRT:-"${DOVECOT_CERTS_DIR}/dovecot-tls.crt"}
DOVECOT_TLS_KEY=${DOVECOT_TLS_KEY:-"${DOVECOT_CERTS_DIR}/dovecot-tls.key"}
DOVECOT_TLS_DH_PARAM=${DOVECOT_TLS_DH_PARAM:-"${DOVECOT_CERTS_DIR}/dovecot-dhparam.pem"}

DOVECOT_TLS_ENFORCE=${DOVECOT_TLS_ENFORCE:-"1"}
DOVECOT_TLS_CIPHER_SUITE=${DOVECOT_TLS_CIPHER_SUITE:-"HIGH:-VERS-TLS-ALL:+VERS-TLS1.2:+VERS-TLS1.3:!SSLv3:!SSLv2:!ADH"}

# LDAP
USE_LDAP=${USE_LDAP:-"0"}
LDAP_HOSTS=${LDAP_HOSTS:-"localhost"}
LDAP_BASE_DN=${LDAP_BASE_DN:-"ou=mail,dc=example,dc=org"}
LDAP_BIND_DN=${LDAP_BIND_DN:-"cn=mailAccountReader,ou=Manager,dc=example,dc=org"}
LDAP_BIND_PASSWORD_FILE=${LDAP_BIND_PASSWORD_FILE:-"/etc/dovecot-secrets/LDAP_BIND_PASSWORD"}
LDAP_USE_TLS=${LDAP_USE_TLS:-"1"}
LDAP_TLS_CA_CRT=${LDAP_TLS_CA_CRT:-""}

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

    # setup vmail user. If not needed, setup /var/spool/vmail
    # for local delivery.

    if [ "${USE_VMAIL_USER}" = "1" ]; then

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
	fi
	# Fix permissions in every case.
	chown vmail:vmail /var/spool/vmail
	chmod 775 /var/spool/vmail

	sed -i -e "s|^#mail_uid =.*|mail_uid = vmail|g" /etc/dovecot/conf.d/10-mail.conf
	sed -i -e "s|^#mail_gid =.*|mail_gid = vmail|g" /etc/dovecot/conf.d/10-mail.conf
    else
	if [ ! -d /var/spool/vmail ]; then
            mkdir -p /var/spool/vmail
	fi
	# Fix permissions in every case.
	chmod 1777 /var/spool/vmail
    fi
}

setup_default_config() {

    mkdir -p "${DOVECOT_RUN_DIR}"

    [ -z "$(ls -A /etc/dovecot)" ] || return

    # Only continue
    cp -a /usr/share/dovecot/example-config/* /etc/dovecot/

    sed -i -e 's|^#log_path =.*|log_path = /dev/stderr|g' /etc/dovecot/conf.d/10-logging.conf
    sed -i -e 's|^#auth_verbose =.*|auth_verbose = yes|g' /etc/dovecot/conf.d/10-logging.conf

    if [ "${DEBUG}" = "1" ]; then
	# Enable some debug informations in conf.d/10-logging.conf
	sed -i -e 's|^#auth_debug =.*|auth_debug = yes|g' /etc/dovecot/conf.d/10-logging.conf
	sed -i -e 's|^#mail_debug =.*|mail_debug = yes|g' /etc/dovecot/conf.d/10-logging.conf
	sed -i -e 's|^#verbose_ssl =.*|verbose_ssl = yes|g' /etc/dovecot/conf.d/10-logging.conf
    fi

    # Don't allow plaintext authentication
    sed -i -e 's|^#disable_plaintext_auth =.*|disable_plaintext_auth = yes|g' /etc/dovecot/conf.d/10-auth.conf

    # Where to find the mailfolders and which uid/gid to use
    sed -i -e 's|^#mail_location =.*|mail_location = maildir:/var/spool/vmail/%n|g' /etc/dovecot/conf.d/10-mail.conf

    echo -e "#default_process_limit = 100\n#default_client_limit = 1000\n" > /etc/dovecot/conf.d/10-master.conf

    local PROTOCOLS=""
    if [ "${ENABLE_IMAP}" = "1" ]; then
	PROTOCOLS="imap ${PROTOCOLS}"
	cat << 'EOT' >> /etc/dovecot/conf.d/10-master.conf
service imap-login {
    inet_listener imap {
        port = 143
    }
    inet_listener imaps {
        port = 993
        ssl = yes
    }

    service_count = 1
    process_min_avail = 1
}

EOT
    fi

    if [ "${ENABLE_POP3}" = "1" ]; then
	PROTOCOLS="pop3 ${PROTOCOLS}"
	cat << 'EOT' >> /etc/dovecot/conf.d/10-master.conf
service pop3-login {
  inet_listener pop3 {
    port = 110
  }
  inet_listener pop3s {
    port = 995
    ssl = yes
  }
}

EOT
    fi

    if [ "${ENABLE_LMTP}" = "1" ]; then
	PROTOCOLS="lmtp ${PROTOCOLS}"
	echo "service lmtp {" >> /etc/dovecot/conf.d/10-master.conf
	[ "${USE_VMAIL_USER}" = "1" ]  && echo "  user = vmail" >> /etc/dovecot/conf.d/10-master.conf
	cat << 'EOT' >> /etc/dovecot/conf.d/10-master.conf
  inet_listener lmtp {
    # address = 192.168.0.24 127.0.0.1 ::1
    port = 24
  }
}
EOT

	if [ "${ENABLE_SIEVE}" = "1" ]; then
	    cat << 'EOT' > /etc/dovecot/conf.d/20-lmtp.conf
protocol lmtp {
  #mail_fsync = optimized
  mail_plugins = $mail_plugins sieve
}
EOT
	    sed -i -e 's|sieve =.*|sieve = file:/var/spool/vmail/%n/sieve;active=/var/spool/vmail/%n/.dovecot.sieve|g' /etc/dovecot/conf.d/90-sieve.conf

	    if [ "${ENABLE_MANAGESIEVE}" = "1" ]; then
		cat << 'EOT' > /etc/dovecot/conf.d/20-managesieve.conf
protocols = $protocols sieve

service managesieve-login {
  inet_listener sieve {
    port = 4190
  }

  # Number of connections to handle before starting a new process. Typically
  # the only useful values are 0 (unlimited) or 1. 1 is more secure, but 0
  # is faster. <doc/wiki/LoginProcess.txt>
  service_count = 1
}
EOT
	    fi
	fi
    fi

    sed -i -e "s|^#protocols =.*|protocols = ${PROTOCOLS}|g" /etc/dovecot/dovecot.conf
}

setup_ldap() {
    [ "${USE_LDAP}" = "1" ] || return

    echo "Configure LDAP..."

    # Disable enabled auth includes and add ldap
    sed -i -e 's|^!include\(.*\)|#!include\1|g' /etc/dovecot/conf.d/10-auth.conf
    echo "!include auth-ldap.conf.ext" >> /etc/dovecot/conf.d/10-auth.conf

    sed -i -e "s|^#hosts =.*|hosts = ${LDAP_HOSTS}|g" /etc/dovecot/dovecot-ldap.conf.ext
    sed -i -e "s|^base =.*|base = ${LDAP_BASE_DN}|g" /etc/dovecot/dovecot-ldap.conf.ext
    sed -i -e 's|^#ldap_version =.*|ldap_version = 3|g' /etc/dovecot/dovecot-ldap.conf.ext
    sed -i -e "s|^#dn =.*|dn = ${LDAP_BIND_DN}|g" /etc/dovecot/dovecot-ldap.conf.ext
    file_env LDAP_BIND_PASSWORD
    sed -i -e "s|^#dnpass =.*|dnpass = ${LDAP_BIND_PASSWORD}|g" /etc/dovecot/dovecot-ldap.conf.ext
    sed -i -e 's|^#auth_bind =.*|auth_bind = yes|g' /etc/dovecot/dovecot-ldap.conf.ext
    sed -i -e "s|^#auth_bind_userdn =.*|auth_bind_userdn = uid=%u,${LDAP_BASE_DN}|g" /etc/dovecot/dovecot-ldap.conf.ext
    sed -i -e 's|^#scope =.*|scope = subtree|g' /etc/dovecot/dovecot-ldap.conf.ext
    sed -i -e 's|^#user_attrs =.*|user_attrs = homeDirectory=home,uidNumber=uid,gidNumber=gid|g' /etc/dovecot/dovecot-ldap.conf.ext
    sed -i -e 's/^#user_filter =.*/user_filter = (\&(objectClass=posixAccount)(|(uid=%u)(maildrop=%u)))/g' /etc/dovecot/dovecot-ldap.conf.ext
    if [ "${LDAP_USE_TLS}" = "1" ]; then
	sed -i -e 's|^#tls =.*|tls = yes|g' /etc/dovecot/dovecot-ldap.conf.ext
	if [ -n "${LDAP_TLS_CA_CRT}" ]; then
	    sed -i -e "s|^#tls_ca_cert_file =.*|tls_ca_cert_file = ${LDAP_TLS_CA_CRT}|g" /etc/dovecot/dovecot-ldap.conf.ext
	fi
    fi
# XXX tls_require_cert = hard
}

function setup_tls() {
    [ "${DOVECOT_TLS}" = "1" ] || return

    echo "Add TLS config..."

    mkdir -p "${DOVECOT_CERTS_DIR}"
    if [ ! -e "$DOVECOT_TLS_CRT" ] || [ ! -e "$DOVECOT_TLS_KEY" ]; then
	if ! /common-scripts/ssl-helper "$DOVECOT_TLS_CRT" "$DOVECOT_TLS_KEY" "$DOVECOT_TLS_CA_CRT" "$DOVECOT_TLS_CA_KEY"; then
	    exit 1
	fi
    fi

    # create DHParamFile if not found
    if [ ! -f "${DOVECOT_TLS_DH_PARAM}" ]; then
        openssl genpkey -genparam -algorithm DH \
                -out "${DOVECOT_TLS_DH_PARAM}" \
                -pkeyopt dh_paramgen_prime_len:2048
        chmod 600 "${DOVECOT_TLS_DH_PARAM}"
    fi

    sed -i -e "s|^ssl_cipher_list =.*|ssl_cipher_list = ${DOVECOT_TLS_CIPHER_SUITE}|g" /etc/dovecot/conf.d/10-ssl.conf
    sed -i -e 's|^ssl_prefer_server_ciphers =.*|ssl_prefer_server_ciphers = yes|g' /etc/dovecot/conf.d/10-ssl.conf
    sed -i -e "s|^#ssl_cert =.*|ssl_cert = <${DOVECOT_TLS_CRT}|g" /etc/dovecot/conf.d/10-ssl.conf
    sed -i -e "s|^#ssl_key =.*|ssl_key = <${DOVECOT_TLS_KEY}|g" /etc/dovecot/conf.d/10-ssl.conf
    sed -i -e "s|^#ssl_dh =.*|ssl_dh = <${DOVECOT_TLS_DH_PARAM}|g" /etc/dovecot/conf.d/10-ssl.conf

    # Enforce TLS
    if [ "${DOVECOT_TLS_ENFORCE}" = "1" ]; then
        echo "Enforce TLS..."
	sed -i -e 's|^#ssl =.*|ssl = required|g' /etc/dovecot/conf.d/10-ssl.conf
    fi
}

###
### Main function
###

# if command starts with an option, prepend dovecot
if [ "${1:0:1}" = '-' ]; then
        set -- /usr/sbin/dovecot "$@"
fi

# Generic setup
setup_timezone
setup_default_config
setup_vmail_user
setup_ldap
setup_tls
echo "Updating certificate store..."
update-ca-certificates

exec "$@"
