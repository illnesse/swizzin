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

user=$(cut -d: -f1 < /root/.master.info)

# add-apt-repository --yes ppa:deadsnakes/ppa
# apt_update


apt_install git python3 python3-setuptools

cd /opt
echo_progress_start "Cloning latest Tautulli repo"
git clone https://github.com/Tautulli/Tautulli.git tautulli >> "${log}" 2>&1
# pip install backports.zoneinfo >> "${log}" 2>&1
echo_progress_done

echo_progress_start "Adding user and setting up Tautulli"
addgroup tautulli >> "${log}" 2>&1
adduser --system --no-create-home tautulli --ingroup tautulli >> "${log}" 2>&1
chown -R tautulli:tautulli /opt/tautulli
echo_progress_done

echo_progress_start "Enabling Tautulli Systemd configuration"
# cp /opt/tautulli/init-scripts/init.systemd /lib/systemd/system/tautulli.service

cat > /etc/systemd/system/tautulli.service << PPY
# Tautulli - Stats for Plex Media Server usage
#
# Service Unit file for systemd system manager
#
# INSTALLATION NOTES
#
#   1. Copy this file into your systemd service unit directory (often '/lib/systemd/system')
#      and name it 'tautulli.service' with the following command:
#       cp /opt/Tautulli/init-scripts/init.systemd /lib/systemd/system/tautulli.service
#
#   2. Edit the new tautulli.service file with configuration settings as required.
#      More details in the "CONFIGURATION NOTES" section shown below.
#
#   3. Enable boot-time autostart with the following commands:
#       systemctl daemon-reload
#       systemctl enable tautulli.service
#
#   4. Start now with the following command:
#       systemctl start tautulli.service
#
# CONFIGURATION NOTES
#
#    - The example settings in this file assume that you will run Tautulli as user: tautulli
#    - The example settings in this file assume that Tautulli is installed to: /opt/Tautulli
#
#    - To create this user and give it ownership of the Tautulli directory:
#       1. Create the user:
#           Ubuntu/Debian: sudo addgroup tautulli && sudo adduser --system --no-create-home tautulli --ingroup tautulli
#           CentOS/Fedora: sudo adduser --system --no-create-home tautulli
#       2. Give the user ownership of the Tautulli directory:
#           sudo chown -R tautulli:tautulli /opt/Tautulli
#
#    - Adjust ExecStart= to point to:
#       1. Your Python interpreter (get the path with "command -v python3")
#          - Default: /usr/bin/python3
#       2. Your Tautulli executable
#          - Default: /opt/Tautulli/Tautulli.py
#       3. Your config file (recommended is to put it somewhere in /etc)
#          - Default: --config /opt/Tautulli/config.ini
#       4. Your datadir (recommended is to NOT put it in your Tautulli exec dir)
#          - Default: --datadir /opt/Tautulli
#
#    - Adjust User= and Group= to the user/group you want Tautulli to run as.
#
#    - WantedBy= specifies which target (i.e. runlevel) to start Tautulli for.
#       multi-user.target equates to runlevel 3 (multi-user text mode)
#       graphical.target  equates to runlevel 5 (multi-user X11 graphical mode)

[Unit]
Description=Tautulli - Stats for Plex Media Server usage
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/python3 /opt/tautulli/Tautulli.py --config /opt/tautulli/config.ini --datadir /opt/tautulli --quiet --nolaunch
User=tautulli
Group=tautulli
Restart=on-abnormal
RestartSec=5
StartLimitInterval=90
StartLimitBurst=3

[Install]
WantedBy=multi-user.target

PPY

systemctl enable -q --now tautulli 2>&1 | tee -a $log

echo_progress_done "Tautulli started"

if [[ -f /install/.nginx.lock ]]; then
    echo_progress_start "Configuring nginx"
    i=0
    #some migration got stuck here
    while [[ ! -f /opt/tautulli/config.ini ]] && [[ $i -lt 20 ]]; do
        sleep 2
        ((i++))
    done
    unset i
    bash /usr/local/bin/swizzin/nginx/tautulli.sh
    systemctl reload nginx
    echo_progress_done
else
    echo_info "Tautulli will run on port 8181"
fi
touch /install/.tautulli.lock

echo_success "Tautulli installed"
