#!/bin/bash

if [ -d /etc/apt/sources.list.d ]; then
  curl -sL https://packagecloud.io/golift/pkgs/gpgkey | apt-key add -
  echo "deb https://packagecloud.io/golift/pkgs/ubuntu focal main" > /etc/apt/sources.list.d/golift.list
  apt_update
  apt_install unpackerr
fi

touch /install/.unpackerr.lock
echo_success "unpackerr installed"
