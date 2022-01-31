#!/bin/bash
set -m

# See https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86
# for background of the process and signal handling

DEBUG=${DEBUG:-"0"}

[ "${DEBUG}" -eq "1" ] && set -x

export PATH=/usr/sbin:/sbin:${PATH}
exitcode=0

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

# Kill children
function terminate() {
    # unbind handler
    trap "" CHLD
    # iterate over previously captured PIDs,
    # each identifying a process
    for pid in $pids; do
        # check whether we have permission to
        # kill that process, and if we do not
        # wait for that process to end
        # if we have permission, loop simply
        # continues
        if ! kill -0 $pid 2>/dev/null; then
            wait $pid
            exitcode=$?
        fi
    done

    # if we are here, we have permission to
    # kill all processes identified by $pids
    kill $pids 2>/dev/null
    kill ${!}
    # wait until all children have gone
    wait
}

# CHLD-handler
function term_child_handler() {
    terminate
    exit $exitcode
}

# SIGTERM-handler
function term_handler() {
    terminate
    exit 143; # 128 + 15 -- SIGTERM
}

#
# Main
#

setup_timezone

# Make sure certificates are current
/usr/sbin/update-ca-certificates

if [ -d /etc/spamassassin ] && [ -n "$(ls -A /etc/spamassassin)" ]; then
    cp -av /etc/spamassassin/* /etc/mail/spamassassin/
fi

echo -n "Updating spamassassin rules..."
sa-update
echo " done"

/update-sa-rules.sh &
/start-spamd.sh &

pids=$(jobs -p)

# setup handlers

# does one if the child processes exit?
trap term_child_handler CHLD

# on callback, kill the background process,
# which is `tail -f /dev/null` and execute the specified handler
trap 'kill ${!}; term_handler' SIGTERM

# wait forever
while true
do
    tail -f /dev/null & wait ${!}
done

exit $exitcode
