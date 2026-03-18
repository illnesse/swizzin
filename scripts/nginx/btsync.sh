#!/bin/bash
# Resilio Sync (BTSync) nginx configuration
# Author: swizzin
# Licensed under GNU General Public License v3.0 GPL-3
#
# Resilio Sync's web UI is served at /gui/ internally. The JS app makes all
# API calls to absolute paths like /gui/token.html, so nginx must proxy /gui/
# directly — not rewrite it to a different prefix.
#
# User-facing entry point: https://<hostname>/gui/
# A convenience redirect is added at /resilio -> /gui/

# Get Resilio Sync webui port from config
if [[ -f /etc/resilio-sync/config.json ]]; then
    port=$(grep -oP '"listen"\s*:\s*"[^:]+:\K\d+' /etc/resilio-sync/config.json)
fi

# Fallback to port from seedit4me port file, then hardcoded default
if [[ -z "$port" ]] && [[ -f /home/seedit4me/.btsync_port ]]; then
    port=$(cat /home/seedit4me/.btsync_port)
fi

if [[ -z "$port" ]]; then
    port=8888
fi

if [[ ! -f /etc/nginx/apps/btsync.conf ]]; then
    cat > /etc/nginx/apps/btsync.conf << BTSNGINX
location /gui/ {
    proxy_pass http://127.0.0.1:${port}/gui/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;

    # WebSocket support for sync status updates
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";

    # Timeout settings
    proxy_read_timeout 86400;
    proxy_send_timeout 86400;

    # Buffering
    proxy_buffering off;
    proxy_redirect off;

    # Authentication
    auth_basic "What's the password?";
    auth_basic_user_file /etc/htpasswd;
}

location /gui {
    return 301 \$scheme://\$host/gui/;
}
BTSNGINX
fi
