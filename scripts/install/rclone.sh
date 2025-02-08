#!/bin/bash
#
# [Quick Box :: Install rclone]
#
# GITHUB REPOS
# GitHub _ packages  :   https://github.com/QuickBox/quickbox_packages
# LOCAL REPOS
# Local _ packages   :   /etc/QuickBox/packages
# Author             :   DedSec | d2dyno
# URL                :   https://quickbox.io
#
# QuickBox Copyright (C) 2017 QuickBox.io
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.

# Install fuse
apt_install fuse3
sed -i -e 's/#user_allow_other/user_allow_other/' /etc/fuse.conf

echo_progress_start "Downloading and installing rclone"
# One-liner to check arch/os type, as well as download latest rclone for relevant system.
wget -q https://rclone.org/install.sh -O /tmp/rcloneinstall.sh >> $log 2>&1

# Make sure rclone downloads and installs without error before proceeding
if ! bash /tmp/rcloneinstall.sh; then
    echo_error "Rclone installer failed"
    exit 1
fi

echo_progress_start "Adding rclone multi-user mount service"
user=$(cut -d: -f1 < /root/.master.info)
passwd=$(cut -d: -f2 < /root/.master.info)
cat > /etc/systemd/system/rclone@.service << EOF
[Unit]
Description=rclonemount
After=network.target

[Service]
Type=simple
User=%i
Group=%i
ExecStart=/usr/bin/rclone  \
	rcd \
	--rc-web-gui \
	--rc-web-gui-no-open-browser \
	--rc-user=${user} \
	--rc-pass=${passwd} \
	--rc-addr 127.0.0.1:5572 \
	--rc-baseurl /rclone
ExecStop=/bin/fusermount -u /home/%i/cloud
Restart=on-failure
RestartSec=30
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target

EOF
echo_progress_done

touch /install/.rclone.lock
echo_success "Rclone installed"
#echo_info "Setup Rclone remote named \"gdrive\" And run sudo systemctl start rclone@username.service"

if [[ -f /install/.nginx.lock ]]; then
    bash /usr/local/bin/swizzin/nginx/rclone.sh
    systemctl reload nginx
fi

systemctl enable rclone@${user}.service >> "${log}" 2>&1
systemctl start rclone@${user}.service >> "${log}" 2>&1
