# fetchmail container

The command to run this container is:

```sh
podman run -d --rm --name fetchmail -v /etc/fetchmailrc:/etc/fetchmailrc:ro registry.opensuse.org/opensuse/fetchmail
```

## Description

XXX

## Fetchmail documentation

To read the current fetchmail documentation:

```sh
podman run registry.opensuse.org/opensuse/fetchmail man fetchmail
```

## Supported environment variables:
- `DEBUG=0|1`		Enables debug mode
- `TZ`			Timezone to use
- `POLLING_INTERVAL`	Interval to poll for new mails, default is `600`
- `FETCHALL=[0|1]`	Retrieve both old (seen) and new messages, default `1`
- `SILENT=[0|1]`	Suppresses all progress/status messages
- `SMTP_HOSTS`		Comma seprated list of hosts to forward mail to

## Configuration files
- `/etc/fetchmailrc`	Configuration file for fetchmail
