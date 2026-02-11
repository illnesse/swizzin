#!/bin/bash
# qui removal script for Swizzin
# Install location: /etc/swizzin/scripts/remove/qui.sh
# Author: Seedit4.me

user=$(cut -d: -f1 < /root/.master.info)

echo_progress_start "Stopping qui service"
systemctl disable --now qui
rm /etc/systemd/system/qui.service
systemctl daemon-reload
echo_progress_done

echo_progress_start "Removing qui files"
rm -f /usr/local/bin/qui
rm -rf /home/${user}/.config/qui
rm -rf /var/log/qui
rm -f /etc/nginx/apps/qui.conf
echo_progress_done

echo_progress_start "Reloading nginx"
systemctl reload nginx
echo_progress_done

rm /install/.qui.lock
echo_success "qui removed successfully"
