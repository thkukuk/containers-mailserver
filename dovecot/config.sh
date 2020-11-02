#!/bin/sh
  
#======================================
# Functions...
#--------------------------------------
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

# Move config away as default to fill volumes
mkdir -p /entrypoint/default-config
mv /etc/dovecot/* /entrypoint/default-config/
