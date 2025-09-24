#!/bin/bash

cd /srv/
if [[ ! -f /srv/tools/logs ]]; then
    mkdir -p /srv/tools/logs
fi
touch /srv/tools/logs/output.log
chmod -R 777 /srv/tools/logs
cp -r /usr/local/bin/swizzin/tools/php/* /srv/tools/
chmod 755 /srv/tools/*.sh
chmod +x /srv/tools/*.sh
chown -R www-data: /srv/tools

if ! [ -c /dev/net/tun ]; then
    mkdir /dev/net
    mknod /dev/net/tun c 10 200
    ip tuntap add mode tap
fi

touch /install/.tools.lock

crontab -l | grep -v notify.sh | crontab -
service cron reload

if [[ ! -f /install/.nginx.lock ]]; then
    echo "ERROR: Web server not detected. Please install nginx and restart seedit4me install."
    exit 1
fi

bash /usr/local/bin/swizzin/nginx/tools.sh
