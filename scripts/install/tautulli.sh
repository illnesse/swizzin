#!/bin/bash
#
# Tautulli installer
#
# Author             :   QuickBox.IO | liara
# Ported to swizzin by liara
#
# QuickBox Copyright (C) 2017 QuickBox.io
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
#if [[ -f /install/.tools.lock ]]; then
#  log="/srv/tools/logs/output.log"
#else
#  log="/dev/null"
#fi

MASTER=$(cut -d: -f1 < /root/.master.info)

apt-get update -y -q >> "${SEEDIT_LOG}"  2>&1;
apt-get -y -q install python python-setuptools tzdata >> "${SEEDIT_LOG}"  2>&1

#apt-get -y -q install python-dev libffi-dev
pip install --upgrade cryptography >> "${SEEDIT_LOG}"  2>&1
python -m easy_install --upgrade pyOpenSSL >> "${SEEDIT_LOG}"  2>&1
cd /opt
LATEST=$(curl -s https://api.github.com/repos/tautulli/tautulli/releases/latest | grep "\"name\":" | cut -d : -f 2 | tr -d \", | cut -d " " -f 3)
echo "Downloading latest Tautulli version ${LATEST}" >> "${SEEDIT_LOG}"  2>&1;
mkdir -p /opt/tautulli
curl -s https://api.github.com/repos/tautulli/tautulli/releases/latest | grep "tarball" | cut -d : -f 2,3 | tr -d \", | wget -q -i- -O- | tar xz -C /opt/tautulli --strip-components 1
touch /install/.tautulli.lock

echo "Adding user and setting up Tautulli" >> "${SEEDIT_LOG}"  2>&1;
adduser --system --no-create-home tautulli >> "${SEEDIT_LOG}"  2>&1

echo "Adjusting permissions" >> "${SEEDIT_LOG}"  2>&1;
chown tautulli:nogroup -R /opt/tautulli




echo "Enabling Tautulli Systemd configuration"
cat > /etc/systemd/system/tautulli.service <<PPY
[Unit]
Description=Tautulli - Stats for Plex Media Server usage
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/opt/tautulli/Tautulli.py --quiet --daemon --nolaunch --config /opt/tautulli/config.ini --datadir /opt/tautulli
GuessMainPID=no
Type=forking
User=tautulli
Group=nogroup

[Install]
WantedBy=multi-user.target
PPY

systemctl enable tautulli > /dev/null 2>&1
systemctl start tautulli

if [[ -f /install/.nginx.lock ]]; then
  while [ ! -f /opt/tautulli/config.ini ]
  do
    sleep 2
  done
  bash /usr/local/bin/swizzin/nginx/tautulli.sh
  service nginx reload
fi

echo "Tautulli Install Complete!" >> "${SEEDIT_LOG}"  2>&1;
#sleep 5
#echo >> "${SEEDIT_LOG}"  2>&1;
#echo >> "${SEEDIT_LOG}"  2>&1;
#echo "Close this dialog box to refresh your browser" >> "${SEEDIT_LOG}"  2>&1;
