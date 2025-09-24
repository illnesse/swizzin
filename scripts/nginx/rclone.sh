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

if [[ ! -f /etc/nginx/apps/rclone.conf ]]; then
    cat > /etc/nginx/apps/rclone.conf << RCLOAD
location /rclone/ {
  include /etc/nginx/snippets/proxy.conf;
  proxy_pass http://127.0.0.1:5572;

#  proxy_set_header Accept-Encoding "";
#  sub_filter_types text/css text/xml text/javascript;
#  sub_filter 'static/' 'rclone/static/';
#  sub_filter_once off;

#  auth_basic "What's the password?";
#  auth_basic_user_file /etc/htpasswd.d/htpasswd.seedit4me;
}

RCLOAD

fi
