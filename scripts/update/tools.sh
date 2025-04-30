#! /bin/bash

#!/bin/bash
input="/etc/swizzin/sources/logo/logo1"
while IFS= read -r line; do
    colorprint "${green}${bold} $line"
done < "$input"
/usr/local/bin/swizzin/remove/tools.sh
/usr/local/bin/swizzin/install/tools.sh

cp /etc/swizzin/sources/motd/motd /etc/motd

. /etc/swizzin/sources/functions/php
restart_php_fpm
systemctl reload nginx

echo_progress_start "temp fix apt repos 1"

sed -i "s%http://ppa.launchpad.net/ondrej/php/ubuntu%http://apt.seedit4.me/mirror/ppa.launchpad.net/ondrej/php/ubuntu%g" /etc/apt/sources.list.d/ondrej-ubuntu-php-bionic.list
sed -i "s%http://archive.ubuntu.com/ubuntu%http://apt.seedit4.me/mirror/archive.ubuntu.com/ubuntu%g" /etc/apt/sources.list

echo "test apt"
#ppa.launchpad.net/
#deb http://ppa.launchpad.net/ondrej/php/ubuntu bionic main
# deb-src http://ppa.launchpad.net/ondrej/php/ubuntu bionic main

echo_progress_done "done"
