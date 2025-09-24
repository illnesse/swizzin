#!/bin/bash
# autobrr remover
# ludviglundgren 2021 for Swizzin

#shellcheck source=sources/functions/utils
. /etc/swizzin/sources/functions/utils

function _remove_flaresolverr() {
    systemctl disable --now -q flaresolverr

    cd /
    rm -f /etc/systemd/system/flaresolverr.service
    rm -rf /opt/flaresolverr

    rm -rf /opt/.venv/flaresolverr

    apt_remove chromium xvfb

    systemctl daemon-reload -q
    systemctl reload nginx

    rm /install/.flaresolverr.lock
}

_remove_flaresolverr
