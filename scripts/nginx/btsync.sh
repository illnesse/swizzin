#!/bin/bash
# Nginx configuration for Resilio Sync (BTSync)
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
MASTER=$(cut -d: -f1 < /root/.master.info)
port=$(cat /home/seedit4me/.btsync_port)
if [[ ! -f /etc/nginx/apps/btsync.conf ]]; then
    # Bind webui to localhost only so it's only reachable via nginx
    sed -i "s/\"listen\" : \"0.0.0.0:${port}\"/\"listen\" : \"127.0.0.1:${port}\"/" /etc/resilio-sync/config.json
    systemctl restart resilio-sync

    cat > /etc/nginx/apps/btsync.conf << BTSYNC
location /btsync/ {
  include /etc/nginx/snippets/proxy.conf;
  proxy_pass http://127.0.0.1:${port}/gui/;

  proxy_set_header Accept-Encoding "";

    # Rewrite hardcoded /gui URLs in JS/HTML
    # sub_filter '/gui/token.html' 'token.html';
    sub_filter '/gui/' '/btsync/';
    sub_filter_types text/html text/javascript application/javascript text/css;
    sub_filter_once off;

    proxy_set_header Cookie \$http_cookie;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

    proxy_connect_timeout 300;
    proxy_send_timeout 300;
    proxy_read_timeout 300;
    proxy_buffering off;
}
BTSYNC
fi
