# OpenLDAP container

The command to run this container is:

```sh
podman run -d --rm --name openldap -p 389:389 -p 636:636 registry.opensuse.org/opensuse/openldap
```

In all examples, `podman` can be replaced directly with `docker`.

## Supported environment variables:
- `DEBUG=yes|no`	Enables "set -x" in the entrypoint script
- `TZ`			Timezone to use in the container
- `LDAP_NOFILE` 	Number of open files (ulimt -n)
- `LDAP_PORT`   	Port for ldap:///
- `LDAPS_PORT`		Port for ldaps:///
- `LDAPI_URL`		ldapi url
- `SLAPD_LOG_LEVEL`     slapd debug devel, defaults to `0`
- `LDAP_UID`            UID of ldap user
- `LDAP_GID`		GID of ldap group
- `LDAP_ORGANISATION` 	Organisation name. Defaults to `Example Inc.`
- `LDAP_DOMAIN`		Ldap domain. Defaults to `example.org`
- `LDAP_BASE_DN`	Ldap base DN. If empty automatically set from `LDAP_DOMAIN` value. Defaults to (`empty`)
- `LDAP_ADMIN_PASSWORD`	Ldap Admin password. Defaults to `admin`
- `LDAP_CONFIG_PASSWORD`	Ldap Config password. Defaults to `config`


## Data persistence volumes
- `/etc/openldap/slapd.d`	slapd configuration files
- `/var/lib/ldap`	OpenLDAP database
