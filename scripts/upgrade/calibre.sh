#!/usr/bin/env bash

if [ ! -f /install/.calibre.lock ]; then
    echo_error "Calibre is not installed"
    exit 1
fi

case "$(_os_arch)" in
    amd64)
        wget https://download.calibre-ebook.com/linux-installer.sh -O /tmp/calibre-installer.sh >> $log 2>&1

        #quick stupid fix for glibc mismatch
        sed -i "s|(2, 31)|(2, 11)|g" /tmp/calibre-installer.sh
        sed -i "s|(2, 34)|(2, 11)|g" /tmp/calibre-installer.sh
        sed -i "s|(2, 35)|(2, 11)|g" /tmp/calibre-installer.sh

        # Pinned to 6.29.0: newer calibre needs freetype >= 2.11 (FT_Get_Color_Glyph_Paint)
        # for Qt WebEngine, which focal's system freetype (2.10.x) doesn't provide. Keep in
        # sync with scripts/install/calibre.sh. Unpin once the base OS ships freetype >= 2.11.
        if ! bash /tmp/calibre-installer.sh version=6.29.0 install_dir=/opt >> $log 2>&1; then
            echo_error "failed to upgrade calibre"
            exit 1
        fi
        ;;
    *)
        # echo_info "No upgrader yet! Your installation is currently managed by apt. Please use that in the meantime"
        apt_install --only-upgrade calibre
        ;;
esac
