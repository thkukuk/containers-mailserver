# opendkim container

The command to run this container is:

```sh
podman run -d --rm --name opendkim -e DKIM_DOMAINS=example.com DKIM_AUTOGENERATE=1 -p 8891:8891 registry.opensuse.org/opensuse/opendkim
```

## Description

At container start, RSA key pairs will be generated for each domain if
`DKIM_AUTOGENERATE=1` is set  unless the file
`/etc/opendkim/keys/<domain>/<selector>.private` exists. If the keys
should persist indefinitely, a volume for `/etc/opendkim/keys` needs to be
mounted, otherwise the keys will be deleted when the container is removed.

DNS records to configure can be found in the container log or by running

```
podman exec opendkim cat /etc/opendkim/keys/*/*.txt
```

The output should be something like

```
$ podman exec opendkim sh -c "cat /etc/opendkim/keys/*/*.txt"

mail._domainkey IN      TXT     ( "v=DKIM1; h=rsa-sha256; k=rsa; s=email; "
          "p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqi64WpMyqVXY1kj2NZ0sVxoWiYs5Z7/bdfqegXbcYv3f95U1Be8Jt52GqYLtm+0J/MgHztKkT/lD7N3ZCFnk1RwxMXm6EFKjfpBaU57NxP/uXzXYNCi50H38h0u8VVbKnhx6qY20Nw7kix4mAwkPe21B7bcaqjegdRJ281S05cddb9No+wJ7zS7KLAp/uJAROYwx4XTmF71XBl"
          "I6wLxYD8TtsQVosvc2EA6MdsEe3Jlr4UC4WODdOGbiyzbTflbj5D2yGWsyzEZKHtCRGoXpomFuBn/wx9N0ub94gSa7pxRcOMKGnHH3yZIwF5VKF8niAaY0cXEIWv9BCXeUlKgLTQIDAQAB" )  ; ----- DKIM key mail for example.com
```

## Supported environment variables:
- `DEBUG=[0|1]`	enables "set -x" in the entrypoint script
- `TZ`		timezone to use
- `DKIM_AUTOGENERATE=1`	 Automatically generate
- `DKIM_DOMAINS=`	 Whitespace-separated list of domains. The default DKIM selector is "mail", but can be changed to "<selector>" using the syntax `DKIM_DOMAINS="<domain1>=<selector1> <domain2> <domain3>=<selector2>"`.
- `DKIM_TRUSTEDHOSTS`	 Whitespace-seperated list of hosts which are trusted.


## Data persistence
- `/etc/opendkim/keys`      Private and public keys for opendkim.
