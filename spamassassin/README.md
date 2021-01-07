# spamassassin container

The command to run this container is:

```sh
podman run -d --rm --name spamassassin -v /srv/spamassassin/etc:/etc/spamassassin -p 783:783 registry.opensuse.org/opensuse/spamassassin
```

## Description

This container provides the spamassassin daemon (spamd). The rules are
updated at every start of the container.

Own adjusted configuration files have to be provided in /etc/spamassassin
inside the container. They will be merged at startup of spamassassin.


## Spamassassin documentation

To read the current spamassassin confiuration file documentation:

```sh
podman run registry.opensuse.org/opensuse/spamassassin man Mail::SpamAssassin::Conf
```

## Supported environment variables:
- `DEBUG=0|1`		Enables debug mode
- `TZ`			Timezone to use

## Volumes
- `/var/lib/spamassassin`	Store the updated rules
- `/etc/spamassassin`		Additional local configuration files
