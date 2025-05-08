#!/bin/bash

echo_progress_start "update apt repo sources 1"

add-apt-repository -y --remove ppa:ondrej/nginx-mainline
add-apt-repository -y ppa:ondrej/nginx

apt-get update -y --allow-releaseinfo-change

if [ -f /etc/apt/sources.list.d/ondrej-ubuntu-php-bionic.list ]; then
    sed -i "s%http://ppa.launchpad.net/ondrej/php/ubuntu%http://apt.seedit4.me/mirror/ppa.launchpad.net/ondrej/php/ubuntu%g" /etc/apt/sources.list.d/ondrej-ubuntu-php-bionic.list
fi
if [ -f /etc/apt/sources.list ]; then
    sed -i "s%http://archive.ubuntu.com/ubuntu%http://apt.seedit4.me/mirror/archive.ubuntu.com/ubuntu%g" /etc/apt/sources.list
fi

echo_progress_done "done"
