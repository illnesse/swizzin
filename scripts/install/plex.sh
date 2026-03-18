#!/bin/bash
#
# [ swizzin :: Install plexmediaserver package]
# Originally authored by: JMSolo for QuickBox
# Modifications to QuickBox package by: liara / PastaGringo
# Maintained and updated for swizzin by: liara
#
# QuickBox Copyright (C) 2017 QuickBox.io
# Modifications for/by swizzin copyright (C) 2019 swizzin.ltd
#
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#

master=$(cut -d: -f1 < /root/.master.info)

echo_progress_start "Installing plex keys and sources ... "
apt_install apt-transport-https
curl -s https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor > /usr/share/keyrings/plex-archive-keyring.gpg 2>> "${log}"
echo "deb [signed-by=/usr/share/keyrings/plex-archive-keyring.gpg] https://downloads.plex.tv/repo/deb public main" > /etc/apt/sources.list.d/plexmediaserver.list
echo

apt_update
echo_progress_done "Sources and keys retrieved and installed"

apt_install plexmediaserver

if [[ ! -d /var/lib/plexmediaserver ]]; then
    mkdir -p /var/lib/plexmediaserver
fi
perm=$(stat -c '%U' /var/lib/plexmediaserver/)
if [[ ! $perm == plex ]]; then
    chown -R plex:plex /var/lib/plexmediaserver
fi
usermod -a -G ${master} plex

sleep 5

systemctl stop plexmediaserver >> $log 2>&1
killall -u plex
sleep 5
mkdir '/home/'${master}'/plex/';
chown -R plex:plex  '/home/'${master}'/plex/';
mv "/var/lib/plexmediaserver/Library/Application Support" /home/${master}/plex
ln -s '/home/'${master}'/plex/Application Support' '/var/lib/plexmediaserver/Library/Application Support'
chown -R plex:plex '/var/lib/plexmediaserver/Library/Application Support'
sleep 5

systemctl start plexmediaserver >> $log 2>&1

# Wait for Plex to create its Preferences.xml on first start
echo_progress_start "Waiting for Plex to initialise preferences"
PREFS_DIR="/home/${master}/plex/Application Support/Plex Media Server"
timeout=60
elapsed=0
while [[ ! -f "${PREFS_DIR}/Preferences.xml" ]] && [[ $elapsed -lt $timeout ]]; do
    sleep 2
    elapsed=$((elapsed + 2))
done
echo_progress_done

# Configure Plex to work behind the nginx reverse proxy so that it does not
# redirect clients back to the raw port 32400.
# We set:
#   allowedNetworks      - trust the loopback so nginx can reach the API
#   customConnections    - the public HTTPS URL Plex advertises to clients
#   RelayEnabled         - disable Plex Relay (we have a direct connection)
if [[ -f "${PREFS_DIR}/Preferences.xml" ]]; then
    echo_progress_start "Configuring Plex reverse proxy preferences"

    # Determine the public hostname (from nginx default site if available)
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        public_host=$(grep -m1 "server_name" /etc/nginx/sites-enabled/default | awk '{print $2}' | sed 's/;//g')
    fi
    # Fall back to the machine's primary IP
    if [[ -z "$public_host" ]] || [[ "$public_host" == "_" ]]; then
        public_host=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
    fi

    systemctl stop plexmediaserver >> $log 2>&1
    sleep 2

    # Inject/update attributes in Preferences.xml using sed.
    # If the attribute already exists we update it; if not we append before />.
    _plex_pref_set() {
        local key="$1"
        local val="$2"
        local prefs="${PREFS_DIR}/Preferences.xml"
        if grep -q "${key}=" "${prefs}"; then
            sed -i "s|${key}=\"[^\"]*\"|${key}=\"${val}\"|g" "${prefs}"
        else
            sed -i "s|/>| ${key}=\"${val}\"/>|" "${prefs}"
        fi
    }

    # Allow nginx (127.0.0.1) to reach Plex without auth token
    _plex_pref_set "allowedNetworks" "127.0.0.1/32"
    # Tell Plex the public HTTPS URL so it advertises it to clients
    _plex_pref_set "customConnections" "https://${public_host}/plex"
    # Disable Plex Relay — we have a direct HTTPS connection via nginx
    _plex_pref_set "RelayEnabled" "0"
    # Disable GDM (local network discovery) — not needed behind a proxy
    _plex_pref_set "GdmEnabled" "0"

    chown plex:plex "${PREFS_DIR}/Preferences.xml"

    systemctl start plexmediaserver >> $log 2>&1
    echo_progress_done "Plex reverse proxy preferences configured"
fi

# Install nginx config if nginx is present
if [[ -f /install/.nginx.lock ]]; then
    echo_progress_start "Installing nginx config for plex"
    bash /etc/swizzin/scripts/nginx/plex.sh
    systemctl reload nginx >> $log 2>&1
    echo_progress_done "Nginx config for plex installed"
fi

touch /install/.plex.lock

echo_success "Plex installed"
