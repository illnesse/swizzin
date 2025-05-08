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
