#!/bin/bash

if [[ -f /install/.quota.lock ]]; then
    if [[ ! -f /etc/sudoers.d/quota ]]; then
        cat > /etc/sudoers.d/quota << EOSUD
#Defaults  env_keep -="HOME"
$(sudoers_quiet_defaults www-data)

Cmnd_Alias   QUOTA = /usr/bin/quota

www-data     ALL = (ALL) NOPASSWD: QUOTA
EOSUD
    fi
    sudoers_strip_unsupported
fi
