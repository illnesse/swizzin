#!/bin/bash

. /etc/swizzin/sources/functions/utils
version=$(github_latest_version "plexdrive/plexdrive")
username=$(cut -d: -f1 < /root/.master.info)

echo_progress_start "Downloading and extracting plexdrive"

mkdir -p /home/$username/plexdrive
mkdir -p /home/$username/plexdrivemount
wget -O /home/$username/plexdrive/plexdrive "https://github.com/plexdrive/plexdrive/releases/download/${version}/plexdrive-linux-amd64" >> "$log" 2>&1
chmod +x /home/$username/plexdrive/plexdrive
echo_progress_done


function _service() {
    echo_progress_start "Creating systemd service"
    cat > "/etc/systemd/system/plexdrive.service" << PLEXDRIVE
[Unit]
Description=Plexdrive
AssertPathIsDirectory=/home/$username/plexdrivemount
After=network-online.target

[Service]
Type=notify
ExecStart=/home/$username/plexdrive/plexdrive mount -v 2 /home/$username/plexdrivemount
ExecStopPost=-/bin/fusermount -quz /home/$username/plexdrivemount
Restart=on-abort

[Install]
WantedBy=default.target
PLEXDRIVE
    systemctl enable -q --now plexdrive 2>&1 | tee -a $log
    echo_progress_done
}

_service

touch /install/.plexdrive.lock
echo_success "plexdrive installed"
