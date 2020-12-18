#!/bin/bash

DEBUG=${DEBUG:-"0"}

[ "${DEBUG}" -eq "1" ] && set -x

POLLING_INTERVAL=${POLLING_INTERVAL:-"600"}
FETCHALL=${FETCHALL:-"1"}
SILENT=${SILENT:-"0"}

export PATH=/usr/sbin:/sbin:${PATH}

setup_timezone() {
    if [ -n "$TZ" ]; then
	TZ_FILE="/usr/share/zoneinfo/$TZ"
	if [ -f "$TZ_FILE" ]; then
	    echo "Setting container timezone to: $TZ"
	    ln -snf "$TZ_FILE" /etc/localtime
	else
	    echo "Cannot set timezone \"$TZ\": timezone does not exist."
	fi
    fi
}

#
# Main
#

OPTS="-d "${POLLING_INTERVAL}" -f /var/lib/fetchmail/fetchmailrc --nodetach --nosyslog"
[ "$DEBUG" -eq "1" ] && OPTS="$OPTS -v"
[ "$FETCHALL" -eq "1" ] && OPTS="$OPTS -a"
[ "$SILENT" -eq "1" ] && OPTS="$OPTS -s"
[ -n "$SMTP_HOSTS" ] && OPTS="$OPTS -S $SMTP_HOSTS"

setup_timezone

/usr/sbin/update-ca-certificates

if [ -e /etc/fetchmailrc ] && [ ! -e /var/lib/fetchmail/fetchmailrc ]; then
  cp /etc/fetchmailrc /var/lib/fetchmail/fetchmailrc
  chown fetchmail:fetchmail /var/lib/fetchmail/fetchmailrc
  chmod 0600 /var/lib/fetchmail/fetchmailrc
fi

# if command starts with an option, prepend fetchmail default command
if [ "${1:0:1}" = '-' ]; then
        set -- /usr/bin/fetchmail "$@"
fi

if [ "$1" = '/usr/bin/fetchmail' ]; then
        exec su fetchmail -s /bin/bash -c "$@ ${OPTS}"
else
	exec "$@"
fi
