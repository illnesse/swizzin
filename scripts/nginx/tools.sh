#!/bin/bash
# QuickBox dashboard installer for Swizzin
# Author: liara
# Copyright (C) 2017 Swizzin
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
IFACE=$(/usr/bin/sudo ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//" | awk '{print $1}')
user=$(cat /root/.master.info | cut -d: -f1)

printf "${IFACE}" > /srv/tools/interface.txt
printf "${user}" > /srv/tools/master.txt
LOCALE=en_GB.UTF-8
LANG=lang_en
echo "*/1 * * * * root bash /usr/local/bin/swizzin/tools/set_interface_tools >/dev/null 2>&1" > /etc/cron.d/set_interface_tools

. /etc/swizzin/sources/functions/php
phpversion=$(php_service_version)
sock="php${phpversion}-fpm"

cat > /etc/nginx/apps/tools.conf << PAN

location /tools {
  alias /srv/tools/ ;
  try_files \$uri \$uri/ /index.php?q=\$uri&\$args;
  index index.php;
  allow all;

  add_header 'Access-Control-Allow-Origin' '*';
  add_header 'Access-Control-Max-Age' '600';
  add_header 'Access-Control-Allow-Headers' '*';
  add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';

  location ~ \.php$
  {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/$sock.sock;
	#fastcgi_index index.php;
	fastcgi_param SCRIPT_FILENAME /srv\$fastcgi_script_name;
  }
}

location /log {
  sendfile on;
  #sendfile_max_chunk 1m;
  #autoindex on;
  try_files \$uri \$uri/ =404;
  alias /srv/tools/logs/output.log;

  add_header 'Content-Type' 'text/plain';
  default_type text/plain;

  if (\$request_method = OPTIONS ) {
	add_header Content-Length 0;
	add_header Content-Type text/plain;
	add_header 'Access-Control-Allow-Origin' '*';
	add_header 'Access-Control-Max-Age' '600';
	add_header 'Access-Control-Allow-Headers' '*';
	add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
	return 200;
  }

  add_header 'Access-Control-Allow-Origin' '*';
  add_header 'Access-Control-Max-Age' '600';
  add_header 'Access-Control-Allow-Headers' '*';
  add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
  add_header 'Cache-Control' 'max-age=0,no-cache,no-store,post-check=0,pre-check=0';
  add_header 'Expires' '0';
}
PAN

cat > /etc/sudoers.d/tools << SUD
#secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin/swizzin:/usr/local/bin/swizzin/scripts:/usr/local/bin/swizzin/scripts/install:/usr/local/bin/swizzin/scripts/remove:/usr/local/bin/swizzin/tools"
#Defaults  env_keep -="HOME"

# Host alias specification

# User alias specification

# Cmnd alias specification
Cmnd_Alias   S4CLEANMEM = /usr/local/bin/swizzin/tools/clean_mem
Cmnd_Alias   S4CLAIMPLEX = /srv/tools/plexclaim.sh
Cmnd_Alias   S4GENERALCMNDS = /usr/sbin/repquota, /bin/systemctl, /usr/bin/systemctl, /bin/ip, /usr/sbin/ip


www-data     ALL = (ALL) NOPASSWD: S4CLEANMEM, S4GENERALCMNDS, S4CLAIMPLEX

SUD
service nginx force-reload
