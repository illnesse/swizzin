#!/bin/bash

systemctl stop sonarr
systemctl disable sonarr
sudo apt-get remove -y sonarr >/dev/null 2>&1
sudo apt-get -y autoremove >/dev/null 2>&1
rm -f /etc/apt/sources.list.d/sonarr.list
rm -f /etc/nginx/apps/sonarr3.conf
rm -rf /var/lib/sonarr/
sudo rm /install/.sonarr3.lock
service nginx reload
