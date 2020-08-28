#!/bin/sh
  
#======================================
# Functions...
#--------------------------------------
test -f /.profile && . /.profile

#======================================
# Greeting...
#--------------------------------------
echo "Configure image: [$kiwi_iname]..."

# Fix path so that update-ca-certificates does not complain
# [bsc#1175340]
rm /etc/ssl/certs && ln -sf /var/lib/ca-certificates/pem /etc/ssl/certs
