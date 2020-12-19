#!/bin/bash

DEBUG=${DEBUG:-"0"}

[ "${DEBUG}" -eq "1" ] && set -x

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

setup_timezone

sa-update

# if command starts with an option, prepend spamd default command
if [ "${1:0:1}" = '-' ]; then
        set -- /usr/sbin/spamd "$@"
fi

exec "$@"
