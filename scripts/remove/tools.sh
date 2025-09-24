#!/bin/bash

#rm -rf /srv/tools
rm /srv/tools/*.*

if [[ -d /srv/tools/vendor ]]; then
    rm -rf /srv/tools/vendor
fi

if [[ -f /etc/nginx/apps/tools.conf ]]; then
    rm -f /etc/nginx/apps/tools.conf
fi

if [[ -f /etc/sudoers.d/tools ]]; then
    rm -f /etc/sudoers.d/tools
fi

if [[ -f /etc/cron.d/set_interface_tools ]]; then
    rm /etc/cron.d/set_interface_tools
fi

if [[ -f /install/.tools.lock ]]; then
    rm /install/.tools.lock
fi
