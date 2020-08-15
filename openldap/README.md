# OpenLDAP container

The command to run this container is:

```sh
podman run -d --rm --name openldap -p 389:389 -p 636:636 registry.opensuse.org/opensuse/openldap
```

In all examples, `podman` can be replaced directly with `docker`.

## Supported environment variables:
- `DEBUG=yes|no`	Enables "set -x" in the entrypoint script.
- `TZ`			Timezone to use in the container.
- `LDAP_NOFILE` 	Number of open files (ulimt -n)
- `LDAP_PORT`   	Port for ldap:///
- `LDAPS_PORT`		Port for ldaps:///
- `LDAPI_URL`		ldapi url


## Data persistence volumes
- `/etc/openldap/slapd.d`	slapd configuration files
- `/var/lib/ldap`	OpenLDAP database
