The command to run this container is:

podman run -d --rm --name opendkim -p 8891:8891 registry.opensuse.org/opensuse/opendkim

At container start, RSA key pairs will be generated for each domain unless the file /etc/opendkim/keys/<domain>/<selector>.private exists. If you want the keys to persist indefinitely, make sure to mount a volume for /etc/opendkim/keys, otherwise they will be destroyed when the container is removed.

DNS records to configure can be found in the container log or by running podman exec <container> cat /etc/opendkim/keys/*/*.txt you should see something like this:

$ podman exec opendkim 'cat /etc/opendkim/keys/*/*.txt'

mail._domainkey.smtp.domain.tld. IN	TXT	( "v=DKIM1; h=sha256; k=rsa; "
	  "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0Dx7wLGPFVaxVQ4TGym/eF89aQ8oMxS9v5BCc26Hij91t2Ci8Fl12DHNVqZoIPGm+9tTIoDVDFEFrlPhMOZl8i4jU9pcFjjaIISaV2+qTa8uV1j3MyByogG8pu4o5Ill7zaySYFsYB++cHJ9pjbFSC42dddCYMfuVgrBsLNrvEi3dLDMjJF5l92Uu8YeswFe26PuHX3Avr261n"
	  "j5joTnYwat4387VEUyGUnZ0aZxCERi+ndXv2/wMJ0tizq+a9+EgqIb+7lkUc2XciQPNuTujM25GhrQBEKznvHyPA6fHsFhe

Supported environment variables:
--------------------------------
DEBUG=yes|no	enables "set -x" in the entrypoint script
TZ		timezone to use


Data persistence
----------------
/etc/opendkim/keys      Private and public keys for opendkim.
