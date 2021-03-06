#!/bin/bash

if [[ -f /install/.tools.lock ]]; then
  export SEEDIT_LOG=/srv/tools/logs/output.log
else
  export SEEDIT_LOG=/root/logs/install.log
fi

apt-get -y remove proftpd proftpd-basic vsftpd >> "${SEEDIT_LOG}" 2>&1

rm /install/.proftpd.lock
rm /install/.vsftpd.lock

waitforapt

box install proftpd