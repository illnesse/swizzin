#!/usr/bin/env bash
# Seerr remove script for swizzin

echo_progress_start "Stopping and disabling Seerr service"
systemctl disable --now -q seerr >> "$log" 2>&1
echo_progress_done "Service stopped"

if [[ -f /install/.nginx.lock ]]; then
    echo_progress_start "Removing Seerr nginx configuration"
    rm -f /etc/nginx/apps/seerr.conf
    systemctl reload nginx
    echo_progress_done "Nginx config removed"
fi

echo_progress_start "Removing Seerr files"
rm -f /etc/systemd/system/seerr.service
systemctl daemon-reload
rm -rf /opt/seerr
rm -rf /etc/seerr
echo_progress_done "Seerr files removed"

echo_progress_start "Removing seerr system user"
if getent passwd seerr > /dev/null 2>&1; then
    deluser --system seerr >> "$log" 2>&1
fi
if getent group seerr > /dev/null 2>&1; then
    delgroup --system seerr >> "$log" 2>&1
fi
echo_progress_done "seerr user removed"

rm -f /install/.seerr.lock
echo_success "Seerr removed"
