# Sample Mail Relay Server

This example will describe how to setup a postfix relay server. All mails will
be forwarded to another mail server, nothing is stored locally.

## Environment variables

The following environment variables needs to be provided:

- `SMTP_RELAYHOST` - Name of the SMTP relay server to use.
- `SERVER_HOSTNAME` - Server hostname. Emails will appear to come from the hostname's domain.
- `SERVER_DOMAIN` - If not set, the domain part of `SERVER_HOSTNAME` will be used.
- `TZ` - Timezone to use in the container. Only optional, not really required.

## Running the container

```sh
podman run -d --name postfix  -p 25:25 -p 587:587 -e SMTP_RELAYHOST=mail.example.com -e SERVER_HOSTNAME=client.example.com -e TZ=Europe/Berlin registry.opensuse.org/opensuse/postfix:latest
```

## Mail Server Authentication

For authentication on the relay host, the account and password to login needs
t be provided in addition.

### Environment variables

- `SMTP_USERNAME` - Username to authenticate with on the relayserver.
- `SMTP_PASSWORD` - Password of the SMTP user, alternative `SMTP_PASSWORD_FILE` could be used to point to a file with the password

### Running the container

```sh
podman run -d --name postfix  -p 25:25 -p 587:587 -e SMTP_USERNAME=user -e SMTP_PASSWORD="password" -e SMTP_RELAYHOST=mail.example.com -e SERVER_HOSTNAME=client.example.com -e TZ=Europe/Berlin registry.opensuse.org/opensuse/postfix:latest
```

### Securing the password

To secure the password, we will not provide it via an environment variable but
a file. For this, a file /etc/postfix-secrets/SMTP_PASSWORD containing the
password needs to be provided:

```sh
mkdir /etc/postfix-secrets
echo "password" > /etc/postfix-secrets/SMTP_PASSWORD
chmod 600 /etc/postfix-secrets/SMTP_PASSWORD

podman run -d --name postfix  -p 25:25 -p 587:587 -v /etc/postfix-secrets:/etc/postfix-secrets -e SMTP_USERNAME=user -e SMTP_PASSWORD_FILE=/etc/postfix-secrets/SMTP_PASSWORD -e SMTP_RELAYHOST=mail.example.com -e SERVER_HOSTNAME=client.example.com -e TZ=Europe/Berlin registry.opensuse.org/opensuse/postfix:latest
```
