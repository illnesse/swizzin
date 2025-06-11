#!/bin/bash

echo_progress_start "Updating apt repository sources"

# Ensure correct Nginx PPA
echo_log_only "Configuring Nginx PPA"
add-apt-repository -y --remove ppa:ondrej/nginx-mainline
if [ -f /etc/apt/sources.list.d/ondrej-ubuntu-nginx-mainline-focal.list ]; then
    rm /etc/apt/sources.list.d/ondrej-ubuntu-nginx-mainline-focal.list
fi

add-apt-repository -y ppa:ondrej/nginx

# Ensure correct PHP PPA by re-adding it. This will fetch the current definition for 'focal'.
echo_log_only "Configuring PHP PPA (re-adding to refresh)"
add-apt-repository -y ppa:ondrej/php

# Attempt to update main Ubuntu repository and Ondrej PHP PPA paths to use mirrors
# This targets /etc/apt/sources.list since /etc/apt/sources.list.d/ is empty.
if [ -f /etc/apt/sources.list ]; then
    echo_log_only "Attempting to update main Ubuntu repository path in /etc/apt/sources.list to use mirror"
    sed -i "s%http://archive.ubuntu.com/ubuntu%http://apt.seedit4.me/mirror/archive.ubuntu.com/ubuntu%g" /etc/apt/sources.list

    # Check if ondrej/php PPA entry exists in the main sources.list and update it
    if grep -q "ppa.launchpad.net/ondrej/php/ubuntu" /etc/apt/sources.list; then
        echo_log_only "Attempting to update ondrej/php PPA path in /etc/apt/sources.list to use mirror"
        sed -i "s%http://ppa.launchpad.net/ondrej/php/ubuntu%http://apt.seedit4.me/mirror/ppa.launchpad.net/ondrej/php/ubuntu%g" /etc/apt/sources.list
    else
        echo_log_only "ondrej/php PPA entry not found in /etc/apt/sources.list for mirror update."
    fi
else
    echo_log_only "/etc/apt/sources.list not found, skipping mirror configuration for main archive and PHP PPA."
fi

echo_progress_done "Repository sources updated"
