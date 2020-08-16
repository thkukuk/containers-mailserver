#!/bin/bash

[ "${DEBUG}" = "yes" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}

LDAP_NOFILE=${LDAP_NOFILE:-1024}
LDAP_PORT=${LDAP_PORT:-389}
LDAPS_PORT=${LDAPS_PORT:-636}
LDAPI_URL=${LDAPI_URL:-"ldapi:///"}
LDAP_UID=${LDAP_UID:-""}
LDAP_GID=${LDAP_GID:-""}
LDAP_BACKEND=${LDAP_BACKEND:-"mdb"}
SLAPD_LOG_LEVEL=${SLAPD_LOG_LEVEL:-0}
SLAPD_CONF=${SLAPD_CONF:-"/etc/openldap/slapd.d"}
SLAPD_RUN_DIR=${SLAPD_RUN_DIR:-"/run/slapd"}
SLAPD_SLP_REG=${SLAPD_SLP_REG:-"-o slp=off"}

# Default values for new database
LDAP_ORGANISATION=${LDAP_ORGANISATION:-"Example Inc."}
LDAP_DOMAIN=${LDAP_DOMAIN:-"example.org"}
LDAP_BASE_DN=${LDAP_BASE_DN:-""}

# TLS
LDAP_TLS=${LDAP_TLS:-true}
LDAP_TLS_CA_CRT=${LDAP_TLS_CA_CRT:-"/etc/openldap/certs/ca.crt"}
LDAP_TLS_CRT=${LDAP_TLS_CRT:-"/etc/openldap/certs/tls.crt"}
LDAP_TLS_KEY=${LDAP_TLS_KEY:-"/etc/openldap/certs/tls.key"}
LDAP_TLS_DH_PARAM=${LDAP_TLS_DH_PARAM:-"/etc/openldap/certs/dhparam.pem"}

LDAP_TLS_ENFORCE=${LDAP_TLS_ENFORCE:-false}
LDAP_TLS_CIPHER_SUITE=${LDAP_TLS_CIPHER_SUITE:-"HIGH:-VERS-TLS-ALL:+VERS-TLS1.2:+VERS-TLS1.3:!SSLv3:!SSLv2:!ADH"}
LDAP_TLS_VERIFY_CLIENT=${LDAP_TLS_VERIFY_CLIENT:-demand}


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

    # Fix permissions
    chown -R ldap:ldap /var/lib/ldap
    chown -R ldap:ldap /etc/openldap
}

init_slapd() {

    CNT_VAR="$(ls /var/lib/ldap)"
    CNT_ETC="$(ls /etc/openldap/slapd.d)"
    # Do nothing if we have a config file or a database
    if [ -n "${CNT_VAR}" ] && [ -n "$CNT_ETC" ]; then
	return
    elif [ -z "${CNT_VAR}" ] && [ -n "$CNT_ETC" ]; then
	 echo "ERROR: the database directory (/var/lib/ldap) is empty but not the config directory (/etc/openldap/slapd.d)" >&2
	 exit 1
    elif [ -n "${CNT_VAR}" ] && [ -z "$CNT_ETC" ]; then
	echo "ERROR: the config directory (/etc/openldap/slapd.d) is empty but not the database directory (/var/lib/ldap)" >&2
	exit 1
    fi

    # Helper functions

    function get_ldap_base_dn() {
	# if LDAP_BASE_DN is empty set value from LDAP_DOMAIN
	if [ -z "$LDAP_BASE_DN" ]; then
	    IFS='.' read -ra LDAP_BASE_DN_TABLE <<< "$LDAP_DOMAIN"
	    for i in "${LDAP_BASE_DN_TABLE[@]}"; do
		EXT="dc=$i,"
		LDAP_BASE_DN=$LDAP_BASE_DN$EXT
	    done
	    LDAP_BASE_DN=${LDAP_BASE_DN::-1}
	fi
    }

    function init_slapd_d() {
	local initldif failed

        echo "Creating initial slapd configuration... "

        # Create the slapd.d directory.
        rm -rf "${SLAPD_CONF}/cn=config" "${SLAPD_CONF}/cn=config.ldif"
        mkdir -p "${SLAPD_CONF}"
        initldif=$(mktemp -t slapadd.XXXXXX)
	sed -e "s|@SUFFIX@|${LDAP_BASE_DN}|g" \
	    -e "s|@PASSWORD@|${LDAP_ADMIN_PASSWORD}|g" \
	    /entrypoint/slapd.init.ldif > "${initldif}"

	slapadd -F "${SLAPD_CONF}" -b "cn=config" \
		-l "${initldif}" || failed=1
        if [ "$failed" ]; then
            rm -f "${initldif}"
	    echo "Loading initial configuration failed!" >&2
            exit 1
        fi

        rm -f "${initldif}"
    }

    function create_new_directory() {
        local dc

	dc="$(echo "${LDAP_DOMAIN}" | sed 's/^\.//; s/\..*$//')"

        echo "Creating LDAP directory... " >&2

        initldif=$(mktemp -t slapadd.XXXXXX)
        cat <<-EOF > "${initldif}"
		dn: ${LDAP_BASE_DN}
		objectClass: top
		objectClass: dcObject
		objectClass: organization
		o: ${LDAP_ORGANISATION}
		dc: $dc

		dn: cn=admin,${LDAP_BASE_DN}
		objectClass: simpleSecurityObject
		objectClass: organizationalRole
		cn: admin
		description: LDAP administrator
		userPassword: ${LDAP_ADMIN_PASSWORD}
	EOF

	slapadd -F "${SLAPD_CONF}" -b "${LDAP_BASE_DN}" \
                -l "${initldif}" || failed=1
        if [ "$failed" ]; then
            rm -f "${initldif}"
	    echo "Loading initial configuration failed!" >&2
            exit 1
        fi

        rm -f "${initldif}"
    }

    function ldap_add_or_modify() {
	local LDIF_FILE=$1

	echo "Processing file ${LDIF_FILE}"
	sed -i "s|@LDAP_BASE_DN@|${LDAP_BASE_DN}|g" "${LDIF_FILE}"
	sed -i "s|@LDAP_BACKEND@|${LDAP_BACKEND}|g" "${LDIF_FILE}"
	sed -i "s|@LDAP_DOMAIN@|${LDAP_DOMAIN}|g" "${LDIF_FILE}"

	if grep -iq changetype "${LDIF_FILE}" ; then
            ldapmodify -Y EXTERNAL -Q -H ldapi:/// -D "cn=admin,${LDAP_BASE_DN}" -w "${LDAP_ADMIN_PASSWORD}" -f "${LDIF_FILE}"
	else
            ldapadd -Y EXTERNAL -Q -H ldapi:/// -D "cn=admin,${LDAP_BASE_DN}" -w "$LDAP_ADMIN_PASSWORD" -f "${LDIF_FILE}"
	fi
    }

    setup_tls() {
	echo "Add TLS config..."

	# generate a certificate and key with ssl-helper tool if LDAP_CRT and LDAP_KEY files don't exists
	# https://github.com/osixia/docker-light-baseimage/blob/stable/image/service-available/:ssl-tools/assets/tool/ssl-helper
	ssl-helper $LDAP_SSL_HELPER_PREFIX $LDAP_TLS_CRT_PATH $LDAP_TLS_KEY_PATH $LDAP_TLS_CA_CRT_PATH

	# create DHParamFile if not found
	if [ ! -f "${LDAP_TLS_DH_PARAM}" ]; then
	    openssl genpkey -genparam -algorithm DH \
		    -out "${LDAP_TLS_DH_PARAM}" \
		    -pkeyopt dh_paramgen_prime_len:2048

            chmod 600 "${LDAP_TLS_DH_PARAM}"
            chown ldap:ldap "${LDAP_TLS_DH_PARAM}"
	fi

	# adapt tls ldif
	sed -i "s|@LDAP_TLS_CA_CRT_PATH@|${LDAP_TLS_CA_CRT}|g" /entrypoint/tls/enable.ldif
	sed -i "s|@LDAP_TLS_CRT_PATH@|${LDAP_TLS_CRT}|g" /entrypoint/tls/enable.ldif
	sed -i "s|@LDAP_TLS_KEY_PATH@|${LDAP_TLS_KEY}|g" /entrypoint/tls/enable.ldif
	sed -i "s|@LDAP_TLS_DH_PARAM@|${LDAP_TLS_DH_PARAM}|g" /entrypoint/tls/enable.ldif

	sed -i "s|@LDAP_TLS_CIPHER_SUITE@|${LDAP_TLS_CIPHER_SUITE}|g" /entrypoint/tls/enable.ldif
	sed -i "s|@LDAP_TLS_VERIFY_CLIENT@|${LDAP_TLS_VERIFY_CLIENT}|g" /entrypoint/tls/enable.ldif

	ldapmodify -Y EXTERNAL -Q -H ldapi:/// -f /entrypoint/tls/tls-enable.ldif

	# enforce TLS
	if [ "${LDAP_TLS_ENFORCE}" == "true" ]; then
            echo "Enforce TLS..."
            ldapmodify -Y EXTERNAL -Q -H ldapi:/// -f /entrypoint/tls/enforce-enable.ldif
	fi

	# stop OpenLDAP
	echo "Stopping temporary OpenLDAP slapd daemon..."

	SLAPD_PID=$(cat /run/slapd/slapd.pid)
	kill -15 "$SLAPD_PID"
	while [ -e /proc/"$SLAPD_PID" ]; do sleep 0.1; done # wait until slapd is terminated
    }

    echo "Database and config directory are empty..."
    echo "Init new ldap server..."

    file_env 'LDAP_ADMIN_PASSWORD'
    if [ -z "${LDAP_ADMIN_PASSWORD}" ]; then
	echo "LDAP admin password (LDAP_ADMIN_PASSWORD) not set!" >&2
	echo "Using default password 'admin'" >&2
	LDAP_ADMIN_PASSWORD="admin"
    fi
    file_env 'LDAP_CONFIG_PASSWORD'
    if [ -z "${LDAP_CONFIG_PASSWORD}" ]; then
	echo "LDAP config password (LDAP_CONFIG_PASSWORD) not set!" >&2
	echo "Using default password 'config'" >&2
	LDAP_CONFIG_PASSWORD="config"
    fi

    get_ldap_base_dn
    init_slapd_d
    create_new_directory
    chown -R ldap:ldap "${SLAPD_CONF}"
    chown -R ldap:ldap /var/lib/ldap

    # start slapd for further initialization work
    # (No double quote for SLAPD_SLP_REG)
    # shellcheck disable=SC2086
    /usr/sbin/slapd -d "${SLAPD_LOG_LEVEL}" -u ldap -g ldap \
		    -h "ldapi:///" ${SLAPD_SLP_REG} &

    echo "Waiting for OpenLDAP to start..."
    while [ ! -e /run/slapd/slapd.pid ]; do sleep 0.1; done

    echo "Add bootstrap schemas..."

    # add ppolicy schema
    ldapadd -c -Y EXTERNAL -Q -H ldapi:/// -f /etc/openldapldap/schema/ppolicy.ldif

    # XXX convert schemas to ldif
    SCHEMAS=""
    for f in $(find ${CONTAINER_SERVICE_DIR}/slapd/assets/config/bootstrap/schema -name \*.schema -type f|sort); do
        SCHEMAS="$SCHEMAS ${f}"
      done
    ${CONTAINER_SERVICE_DIR}/slapd/assets/schema-to-ldif.sh "$SCHEMAS"

    # XXX add converted schemas
    for f in $(find ${CONTAINER_SERVICE_DIR}/slapd/assets/config/bootstrap/schema -name \*.ldif -type f|sort); do
        log-helper debug "Processing file ${f}"
        # add schema if not already exists
        SCHEMA=$(basename "${f}" .ldif)
        ADD_SCHEMA=$(is_new_schema $SCHEMA)
        if [ "$ADD_SCHEMA" -eq 1 ]; then
            ldapadd -c -Y EXTERNAL -Q -H ldapi:/// -f "$f"
        else
            echo "schema ${f} already exists"
        fi
    done

    # set config password
    LDAP_CONFIG_PASSWORD_ENCRYPTED=$(slappasswd -s "$LDAP_CONFIG_PASSWORD")
    sed -i -e "s|@LDAP_CONFIG_PASSWORD_ENCRYPTED@|${LDAP_CONFIG_PASSWORD_ENCRYPTED}|g" /entrypoint/set-config-password.ldif
    ldap_add_or_modify /entrypoint/set-config-password.ldif
    rm -f /entrypoint/set-config-password.ldif
    ldap_add_or_modify /entrypoint/security.ldif
    rm -f /entrypoint/security.ldif
    ldap_add_or_modify /entrypoint/memberOf.ldif
    ldap_add_or_modify /entrypoint/refint.ldif
    ldap_add_or_modify /entrypoint/index.ldif

    # process config files (*.ldif) in custom directory
    echo "Add image bootstrap ldif..."
    for f in $(find /entrypoint/custom -mindepth 1 -maxdepth 1 -type f -name \*.ldif  | sort); do
	echo "Processing file ${f}"
        ldap_add_or_modify "$f"
    done

    if [ "${LDAP_TLS}" == "true" ]; then
	setup_tls
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

# shellcheck disable=SC1091
test -f /etc/sysconfig/openldap && . /etc/sysconfig/openldap

# Reduce maximum number of number of open file descriptors
# see https://github.com/docker/docker/issues/8231
ulimit -n "$LDAP_NOFILE"

# Generic setup
setup_timezone
setup_ldap_uidgid

if [ "$1" = '/usr/sbin/slapd' ]; then
    if [ ! -d "$SLAPD_RUN_DIR" ]; then
	mkdir -p "$SLAPD_RUN_DIR"
	chown -R ldap:ldap "$SLAPD_RUN_DIR"
    fi

    # slapd specific initialization
    init_ldap_url
    init_ldaps_url
    init_slapd

    echo "Starting OpenLDAP server"
    # (No double quote for SLAPD_SLP_REG)
    # shellcheck disable=SC2086
    exec /usr/sbin/slapd -d "${SLAPD_LOG_LEVEL}" -u ldap -g ldap \
	 -h "$LDAP_URL $LDAPS_URL $LDAPI_URL" ${SLAPD_SLP_REG}
else
    exec "$@"
fi
