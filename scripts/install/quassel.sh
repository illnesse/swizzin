#!/bin/bash
#
# Quassel Installer
#
# Originally written for QuickBox.io. Ported to Swizzin
# Author: liara
#
# QuickBox Copyright (C) 2016
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
#################################################################################

port=$(cat /home/seedit4me/.quassel_port)

#if [[ -f /install/.tools.lock ]]; then
#  log="/srv/tools/logs/output.log"
#else
#  log="/dev/null"
#fi
distribution=$(lsb_release -is)
codename=$(lsb_release -cs)
IP=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
user=$(cut -d: -f1 < /root/.master.info)
. /etc/swizzin/sources/functions/backports

echo "Installing Quassel PPA (Ubuntu) or grabbing latest backport (Debian) ... " >>  "${SEEDIT_LOG}"  2>&1

if [[ $distribution == Ubuntu ]]; then
  echo "Installing Quassel PPA"
  apt-get install -q -y software-properties-common  >>  "${SEEDIT_LOG}"  2>&1
	apt-add-repository ppa:mamarley/quassel -y  >>  "${SEEDIT_LOG}"  2>&1
	apt-get -qq -y --force-yes update  >>  "${SEEDIT_LOG}"  2>&1
  apt-get -q -y install quassel-core  >>  "${SEEDIT_LOG}"  2>&1
else
  if [[ $codename == "buster" ]]; then
    echo "Grabbing latest release"
    apt-get -y -q quassel-core  >>  "${SEEDIT_LOG}"  2>&1
  elif [[ $codename == "stretch" ]]; then
    check_debian_backports
    echo "Grabbing latest backport"
    apt-get -y -q install quassel-core  >>  "${SEEDIT_LOG}"  2>&1
  else
    echo "Grabbing latest backport"
  wget -r -l1 --no-parent --no-directories -A "quassel-core*.deb" https://iskrembilen.com/quassel-packages-debian/  >>  "${SEEDIT_LOG}"  2>&1
  dpkg -i quassel-core*  >>  "${SEEDIT_LOG}"  2>&1
  rm quassel-core*
  apt-get install -f -y -q  >>  "${SEEDIT_LOG}"  2>&1
fi
fi

sleep 3s

sed -i -e 's/4242/'$port'/g' /lib/systemd/system/quasselcore.service
sed -i -e 's/4242/'$port'/g' /etc/default/quasselcore

sleep 3s

mv /etc/init.d/quasselcore /etc/init.d/quasselcore.BAK
systemctl enable --now quasselcore

systemctl restart quasselcore.service


echo "Quassel has now been installed! " >>  "${SEEDIT_LOG}"  2>&1
echo "Please install quassel-client on your personal computer "
echo "and connect to the newly created core at "
echo "${IP}:${port} to set up your account"

touch /install/.quassel.lock
