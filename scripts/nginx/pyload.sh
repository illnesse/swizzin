#!/bin/bash
# Nginx configuration for PyLoad
# Author: liara
# Copyright (C) 2017 Swizzin
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
MASTER=$(cat /root/.master.info | cut -d: -f1)
if [[ ! -f /etc/nginx/apps/pyload.conf ]]; then
cat > /etc/nginx/apps/pyload.conf <<PYLOAD
location /pyload {
  include /etc/nginx/snippets/proxy.conf;
  proxy_pass        http://127.0.0.1:8000/pyload;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd.d/htpasswd.${MASTER};
}
PYLOAD
