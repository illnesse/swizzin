#!/usr/bin/env bash
# Seerr upgrade script for swizzin
# Pulls latest source from main branch, rebuilds and restarts

if [[ ! -f /install/.seerr.lock ]]; then
    echo_error "Seerr is not installed"
    exit 1
fi

#shellcheck source=sources/functions/seerr
. /etc/swizzin/sources/functions/seerr

if systemctl is-active -q seerr; then
    wasActive="true"
    echo_progress_start "Stopping Seerr"
    systemctl stop seerr
    echo_progress_done "Seerr stopped"
fi

seerr_build

if [[ $wasActive == "true" ]]; then
    echo_progress_start "Restarting Seerr"
    systemctl start seerr
    echo_progress_done "Seerr restarted"
fi

echo_success "Seerr upgraded successfully"
