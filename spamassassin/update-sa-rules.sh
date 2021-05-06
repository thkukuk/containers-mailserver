#!/bin/bash

while true; do
    sleep 86400
    echo -n "Updating spamassassin rules..."
    sa-update && kill -HUP "$(cat /run/spamd.pid)"
    echo " done"
done
