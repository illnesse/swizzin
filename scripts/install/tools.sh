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

log="/dev/null"

if [[ -f /lib/systemd/system/php7.3-fpm.service ]]; then
  echo "php setup seems ok"
else
  apt -y -q  remove php7.0 php7.0-fpm php7.0-cli php7.0-common
  LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
  apt -y -q  update
  apt -y -q  install nano php7.3 php7.3-fpm php7.3-cli php7.3-common php7.3-zip php7.3-sqlite3 php7.3-curl php7.3-simplexml
  update-alternatives --set php /usr/bin/php7.3
  sed -i "s/php7.0-fpm/php7.3-fpm/g" /etc/nginx/apps/*.conf
fi

if [[ ! -f /install/.nginx.lock ]]; then
  echo "ERROR: Web server not detected. Please install nginx and restart seedit4me install."
  exit 1
fi

bash /usr/local/bin/swizzin/nginx/tools.sh
touch /install/.tools.lock
