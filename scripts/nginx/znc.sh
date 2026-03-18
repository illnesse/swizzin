#!/bin/bash
# ZNC nginx configuration
# Author: swizzin
# Licensed under GNU General Public License v3.0 GPL-3
#
# ZNC's web admin interface is proxied through nginx SSL terminator.
# ZNC handles its own authentication, so no auth_basic is needed here.
# IRC clients connect directly to ZNC's IRC port (not through nginx).
# The LE cert is also copied into znc.pem so ZNC can offer SSL on its IRC port.

# Get ZNC HTTP port from config (the webadmin listener port)
if [[ -f /home/znc/.znc/configs/znc.conf ]]; then
    port=$(grep -E '^\s*Port\s*=' /home/znc/.znc/configs/znc.conf | awk '{print $3}' | head -1)
fi

# Fallback to default port if config not found or empty
if [[ -z "$port" ]]; then
    port=6667
fi

if [[ ! -f /etc/nginx/apps/znc.conf ]]; then
    cat > /etc/nginx/apps/znc.conf << ZNCNGINX
# ZNC IRC Bouncer - Web Admin Interface
# IRC clients connect directly to ZNC on port ${port}; this proxies only the web UI.
location /znc/ {
    proxy_pass http://127.0.0.1:${port}/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;

    # WebSocket support for ZNC web interface
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    # Timeout settings
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;

    proxy_buffering off;
    proxy_redirect off;
}

location /znc {
    return 301 \$scheme://\$host/znc/;
}
ZNCNGINX
fi
