#!/bin/bash

if [ -d /etc/apt/sources.list.d ]; then
  mkdir -p /etc/apt/keyrings
  curl -sL https://packagecloud.io/golift/pkgs/gpgkey | gpg --dearmor -o /etc/apt/keyrings/golift.gpg
  echo "deb [signed-by=/etc/apt/keyrings/golift.gpg] https://packagecloud.io/golift/pkgs/ubuntu focal main" > /etc/apt/sources.list.d/golift.list
  apt_update
  apt_install unpackerr
fi

touch /install/.unpackerr.lock
echo_success "unpackerr installed"
