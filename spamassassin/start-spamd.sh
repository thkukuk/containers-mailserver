#!/bin/bash

/usr/sbin/spamd \
      --nouser-config \
      --helper-home-dir /var/lib/spamassassin \
      --syslog stderr \
      --pidfile /run/spamd.pid \
      --listen \
      -A 0.0.0.0/0
