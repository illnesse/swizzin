#!/bin/bash

echo_progress_start "Updating apt repository sources"

# Remove deprecated nginx-mainline repository and add recommended nginx repository
if grep -q "nginx-mainline" /etc/apt/sources.list.d/*; then
    echo_log_only "Removing deprecated nginx-mainline repository"
    add-apt-repository -y --remove ppa:ondrej/nginx-mainline
    echo_log_only "Adding recommended nginx repository"
    add-apt-repository -y ppa:ondrej/nginx
fi

# Update PHP repository paths to use mirrors if needed
if [ -f /etc/apt/sources.list.d/ondrej-ubuntu-php-bionic.list ]; then
    echo_log_only "Updating PHP repository path to use mirror"
    sed -i "s%http://ppa.launchpad.net/ondrej/php/ubuntu%http://apt.seedit4.me/mirror/ppa.launchpad.net/ondrej/php/ubuntu%g" /etc/apt/sources.list.d/ondrej-ubuntu-php-bionic.list
fi

# Update main Ubuntu repository paths to use mirrors if needed
if [ -f /etc/apt/sources.list ]; then
    echo_log_only "Updating main Ubuntu repository path to use mirror"
    sed -i "s%http://archive.ubuntu.com/ubuntu%http://apt.seedit4.me/mirror/archive.ubuntu.com/ubuntu%g" /etc/apt/sources.list
fi

echo_progress_done "Repository sources updated successfully"
