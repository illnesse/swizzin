#!/bin/bash
# Plex nginx configuration
# Author: swizzin
# Licensed under GNU General Public License v3.0 GPL-3
#
# Plex is proxied through nginx SSL terminator so it is accessible at:
#   https://<hostname>/plex/   (reverse proxy path)
#   https://<hostname>/web     (direct web UI path)
#
# Plex must be told about the custom connection URL so that it does not
# redirect clients back to the raw port. This is done by writing
# customConnections into Preferences.xml after Plex has started once.

if [[ ! -f /etc/nginx/apps/plex.conf ]]; then
    cat > /etc/nginx/apps/plex.conf << 'PLEXNGINX'
# Plex Web Interface - reverse proxy through nginx SSL
location /plex/ {
    proxy_pass http://127.0.0.1:32400/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $server_name;
    proxy_set_header X-Plex-Client-Identifier $http_x_plex_client_identifier;

    # WebSocket support for Plex
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Buffering settings
    proxy_buffering off;
    proxy_redirect off;

    # Timeout settings for streaming
    proxy_read_timeout 86400;
    send_timeout 100m;

    # Allow large uploads
    client_max_body_size 0;
}

# Direct /web path (Plex Web UI)
location /web {
    proxy_pass http://127.0.0.1:32400/web;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $server_name;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_buffering off;
    proxy_redirect off;
    proxy_read_timeout 86400;
    client_max_body_size 0;
}

# Plex API and media endpoints
location ~ ^/(library|status|photo|media|video|music|playlists|:/|system|updater|diagnostics|identity|:/websockets) {
    proxy_pass http://127.0.0.1:32400;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $server_name;

    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_buffering off;
    proxy_redirect off;
    proxy_read_timeout 86400;
    send_timeout 100m;
    client_max_body_size 0;
}
PLEXNGINX
fi
