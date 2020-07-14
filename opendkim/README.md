The command to run this container is:

podman run -d --rm --name opendkim -p 8891:8891 registry.opensuse.org/opensuse/opendkim


Supported environment variables:
--------------------------------
DEBUG=yes|no	enables "set -x" in the entrypoint script
TZ		timezone to use


Data persistence
----------------
/etc/opendkim/keys      Private and public keys for opendkim.
