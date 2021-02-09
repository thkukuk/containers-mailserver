# containers-mailserver

Simple Container images based on openSUSE busybox container image to build a containerized mail server.

## Description

With this collection of containers you can build your containerized mail server for your kubernetes clusters or run them on a container host with docker and podman. You only need the containers which provide the functionality you really need. So if you don't need opendkim, no need to run that container. And as every service has it's own container, there is no need to update your postfix server only because there is a dovecot update.

## Containers
### OpenLDAP

This container images provides an OpenLDAP server. The initial setup is configured though environment variables and ldif files.

Instructions: [README](openldap/README.md)

### postfix

This image allows you to run POSTFIX as relay or for virtual users, where the users are provided via environment variables, files or LDAP.

Instructions: [README](postfix/README.md)

### dovecot

This image runs Dovecot as IMAP and POP3 email server. The user accounts are fetched from an LDAP server, the Mails are stored in Maildir format in a persistent volume filled by e.g. postfix.

Instructions: [README](dovecot/README.md)

### SpamAssassin

This image runs SpamAssassin to classify mails as Spam for postfix.

Instructions: [README](spamassassin/README.md)

### fetchmail

This image runs fetchmail to pull mails from another IMAP or POP3 server and submit them locally.

Instructions: [README](fetchmail/README.md)

### DKIM

This images provides the `DomainKeys Identified Mail (DKIM)` service
implemented through opendkim and can be used together with the postfix image.

Instructions: [README](opendkim/README.md)

## Examples

- [Simple Mail Relay Server](examples/Simple-Mail-Relay-Server.md)
