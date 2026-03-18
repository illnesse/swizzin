#!/bin/bash
#ZNC Removal

systemctl disable -q znc
systemctl stop -q znc
sudo -u znc crontab -l | sed '/znc/d' | crontab -u znc -
apt_remove znc
userdel -rf znc
groupdel -f znc
rm /install/.znc.lock

# Remove nginx reverse proxy config and reload
if [[ -f /etc/nginx/apps/znc.conf ]]; then
    rm -f /etc/nginx/apps/znc.conf
    if [[ -f /install/.nginx.lock ]]; then
        nginx -t >> "${log}" 2>&1 && systemctl reload nginx >> "${log}" 2>&1
    fi
fi
