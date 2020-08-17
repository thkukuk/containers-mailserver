# OpenLDAP container

The command to run this container is:

```sh
podman run -d --rm --name openldap -p 389:389 -p 636:636 registry.opensuse.org/opensuse/openldap
```

In all examples, `podman` can be replaced directly with `docker`.

## Supported environment variables:
### Generic variables:
- `DEBUG=yes|no`	Enables "set -x" in the entrypoint script
- `TZ`			Timezone to use in the container

### Variables for new database:
- `LDAP_DOMAIN`		Ldap domain. Defaults to `example.org`
- `LDAP_BASE_DN`	Ldap base DN. If empty automatically set from `LDAP_DOMAIN` value. Defaults to (`empty`)
- `LDAP_ORGANISATION`	Organisation name. Defaults to `Example Inc.`
- `LDAP_ADMIN_PASSWORD`	Ldap Admin password. Defaults to `admin`
- `LDAP_CONFIG_PASSWORD`	Ldap Config password. Defaults to `config`
- `LDAP_BACKEND`	Database backend, defaults to `mdb`
- `LDAP_SEED_LDIF_PATH` Path with additional ldif files which will be loaded
- `LDAP_SEED_SCHEMA_PATH`	Path with additional schema which will be loaded

### Variables for TLS
- `LDAP_TLS=true|false`
- `LDAP_TLS_CA_CRT`
- `LDAP_TLS_CRT`
- `LDAP_TLS_KEY`
- `LDAP_TLS_DH_PARAM`
- `LDAP_TLS_ENFORCE=true|false`
- `LDAP_TLS_CIPHER_SUITE`
- `LDAP_TLS_VERIFY_CLIENT`

### Various configuration variables:
- `LDAP_NOFILE` 	Number of open files (ulimt -n), default `1024`
- `LDAP_PORT`   	Port for ldap:///, defaults to `389`
- `LDAPS_PORT`		Port for ldaps:///, defaults to `636`
- `LDAPI_URL`		Ldapi url, defaults to `ldapi:///run/slapd/ldapi`
- `LDAP_UID`            UID of ldap user. All LDAP related files will be changed to this UID
- `LDAP_GID`		GID of ldap group. All LDAP related files will be changed to this GID
- `LDAP_BACKEND`	Database backend, defaults to `mdb`
- `SLAPD_LOG_LEVEL`     Slapd debug devel, defaults to `0`

## Data persistence volumes
- `/etc/openldap/certs`		TLS certificates for slapd
- `/etc/openldap/slapd.d`	Slapd configuration files
- `/var/lib/ldap`		OpenLDAP database
