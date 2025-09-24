#!/bin/bash

echo_log_only "disabling service & cleaning up"
systemctl disable --now -q mountrar2fs
rm /etc/systemd/system/mountrar2fs.service
systemctl daemon-reload -q
rm -rf /home/seedit4me/rar2fsmount
echo_progress_done

rm /install/.rar2fs.lock
