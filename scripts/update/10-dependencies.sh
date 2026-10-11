#!/bin/bash
# Ensures that dependencies are installed and corrects them if that is not the case.

if ! which add-apt-repository > /dev/null; then
    apt_install software-properties-common # Ubuntu may require universe/mutliverse enabled for certain packages so we must ensure repos are enabled before deps are attempted to installed
fi

if [[ $(_os_distro) == "ubuntu" ]]; then
    #Ignore a found match if the line is commented out
    #24.04+ keep the sources in deb822 format under sources.list.d (ubuntu.sources)
    #-y: newer add-apt-repository waits for confirmation otherwise
    for component in universe multiverse restricted; do
        if ! grep -rhs "$component" /etc/apt/sources.list /etc/apt/sources.list.d/ | grep -q -v '^#'; then
            echo_info "Enabling $component repo"
            add-apt-repository -y "$component" >> ${log} 2>&1
            trigger_apt_update=true
        fi
    done
elif [[ $(_os_distro) == "debian" ]]; then
    if ! grep contrib /etc/apt/sources.list | grep -q -v '^#'; then
        echo_info "Enabling contrib repo"
        apt-add-repository contrib >> ${log} 2>&1
        trigger_apt_update=true
    fi
    if ! grep non-free /etc/apt/sources.list | grep -q -v '^#'; then
        echo_info "Enabling non-free repo"
        apt-add-repository non-free >> ${log} 2>&1
        trigger_apt_update=true
    fi
fi
if [[ $trigger_apt_update == "true" ]]; then
    apt_update
fi

#space-separated list of required GLOBAL SWIZZIN dependencies (NOT application specific ones)
dependencies="whiptail git sudo curl wget lsof fail2ban apache2-utils tcl tcl-dev build-essential dirmngr apt-transport-https bc uuid-runtime jq net-tools gnupg2 cracklib-runtime unzip ccze"

apt_install "${dependencies[@]}"
