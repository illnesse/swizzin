#!/bin/bash
# Remove glances from swizzin
#

systemctl disable --now -q glancesweb

if [[ -f /install/.nginx.lock ]]; then
    rm -f /etc/nginx/apps/glances.conf
    systemctl reload nginx
fi

apt_remove glances

rm /install/.glances.lock
