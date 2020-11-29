#!/bin/bash
# Deluge upgrade/downgrade/reinstall script
# Author: liara
if [[ ! -f /install/.deluge.lock ]]; then
	echo "Deluge doesn't appear to be installed. What do you hope to accomplish by running this script?"
	exit 1
fi

#if [[ -f /tmp/.install.lock ]]; then
#  export log="/root/logs/install.log"
#else
#  export log="/dev/null"
#fi

. /etc/swizzin/sources/functions/deluge
whiptail_deluge
whiptail_libtorrent_rasterbar
dver=$(deluged -v | grep deluged | grep -oP '\d+\.\d+\.\d+')
if [[ $dver == 1.3* ]] && [[ $deluge == master ]]; then
	echo "Major version upgrade detected. User-data will be backed-up." >> "${log}" 2>&1
fi
users=($(cut -d: -f1 < /etc/htpasswd))
noexec=$(grep "/tmp" /etc/fstab | grep noexec)

for u in "${users[@]}"; do
	if [[ $dver == 1.3* ]] && [[ $deluge == master ]]; then
		echo "'/home/${u}/.config/deluge' -> '/home/$u/.config/deluge.$$'"
		cp -a /home/${u}/.config/deluge /home/${u}/.config/deluge.$$
	fi
done

if [[ -n $noexec ]]; then
	mount -o remount,exec /tmp
	noexec=1
fi

echo "Checking for outdated deluge install method." >> "${log}" 2>&1
remove_ltcheckinstall
echo "Rebuilding libtorrent ... " >> "${log}" 2>&1
build_libtorrent_rasterbar
cleanup_deluge
echo "Upgrading Deluge. Please wait ... " >> "${log}" 2>&1
build_deluge
if [[ -n $noexec ]]; then
	mount -o remount,noexec /tmp
fi

if [[ -f /install/.nginx.lock ]]; then
	echo "Reconfiguring deluge nginx configs"
	bash /usr/local/bin/swizzin/nginx/deluge.sh
	service nginx reload
fi

echo "Fixing Web Service and Hostlist ... " >> "${log}" 2>&1
dweb_check

for u in "${users[@]}"; do
	echo "Running ltconfig check ..." >> "${log}" 2>&1
	ltconfig
	systemctl try-restart deluged@${u}
	systemctl try-restart deluge-web@${u}
done
