# containers-mailserver

Simple Container images based on openSUSE busybox container image.

## Description

With this collection of containers you can build your containerized mail server for your kubernetes clusters or run them on a container host. You only need the containers which provide the functionality you really need. So if you don't need opendkim, no need to run that container. And as every service has it's own container, there is no need to update your postfix relay only because there is a dovecot update.

## postfix

This image allows you to run POSTFIX internally to centralise outgoing email sending. The embedded postfix enables you to either send messages directly or relay them. to your company's main server.

This is a _server side_ POSTFIX image best useable as relay for your applications sending emails.

Instructions: [README](postfix/README.md)
