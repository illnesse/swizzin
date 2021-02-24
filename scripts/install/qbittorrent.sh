#!/bin/bash
# qBittorrent Installer for swizzin
# Author: liara

# Source the required functions
. /etc/swizzin/sources/functions/qbittorrent
. /etc/swizzin/sources/functions/libtorrent
. /etc/swizzin/sources/functions/utils
. /etc/swizzin/sources/functions/fpm

users=($(_get_user_list))

if [[ -n $1 ]]; then
    user=$1
    qbittorrent_user_config ${user}
    if [[ -f /install/.nginx.lock ]]; then
        echo_progress_start "Configuring nginx"
        bash /etc/swizzin/scripts/nginx/qbittorrent.sh
        systemctl reload nginx
        echo_progress_done
    fi
    exit 0
fi

releases=$(git ls-remote -t --refs https://github.com/qbittorrent/qBittorrent.git | awk '{sub("refs/tags/release-", ""); print $2 }' | sort -r)
latestv41=$(echo "$releases" | grep -m1 -oP '4\.1\.\d?.?\d')
latestv42=$(echo "$releases" | grep -m1 -oP '4\.2\.\d?.?\d')
latestv=$(echo "$releases" | grep -m1 -oP '\d.\d?.?\d?.?\d')
export qbittorrent=${latestv42}

#whiptail_qbittorrent
check_client_compatibility
if ! skip_libtorrent_rasterbar; then
    export libtorrent=RC_1_1
    #whiptail_libtorrent_rasterbar
    echo_progress_start "Building libtorrent-rasterbar"
    build_libtorrent_rasterbar
    echo_progress_done "Build completed"
fi

echo_progress_start "Building qBittorrent"
build_qbittorrent
echo_progress_done

qbittorrent_service
for user in ${users[@]}; do
    echo_progress_start "Enabling qbittorrent for $user"
    qbittorrent_user_config ${user}
    systemctl enable -q --now qbittorrent@${user} 2>&1 | tee -a $log
    echo_progress_done "Started qbt for $user"
done
if [[ -f /install/.nginx.lock ]]; then
    echo_progress_start "Configuring nginx"
    bash /etc/swizzin/scripts/nginx/qbittorrent.sh
    systemctl reload nginx >> $log 2>&1
    echo_progress_done
fi

touch /install/.qbittorrent.lock
