#!/bin/bash
log="/root/logs/swizzin.log"

systemctl stop sonarr
systemctl disable sonarr
apt_remove --purge sonarr
rm -f /etc/apt/sources.list.d/sonarr.list


rm -rf /var/lib/sonarr
rm -rf /usr/lib/sonarr

if [[ -f /install/.nginx.lock ]]; then 
    rm /etc/nginx/apps/sonarrv3.conf
    systemctl reload nginx >> $log 2>&1
fi

rm /install/.sonarrv3.lock