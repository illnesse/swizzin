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

#echo_info "Please visit https://www.plex.tv/claim, login, copy your plex claim token to your clipboard and paste it here. This will automatically claim your server! Otherwise, you can leave this blank and to tunnel to the port instead."
#echo_query "Insert your Plex claim token" "e.g. 'claim-...' or blank"
#read 'claim'

#versions=https://plex.tv/api/downloads/1.json
#wgetresults="$(wget "${versions}" -O -)"
#releases=$(grep -ioe '"label"[^}]*' <<<"${wgetresults}" | grep -i "\"distro\":\"ubuntu\"" | grep -m1 -i "\"build\":\"linux-ubuntu-x86_64\"")
#latest=$(echo ${releases} | grep -m1 -ioe 'https://[^\"]*')

echo_progress_start "Setting up Plex repository..."
apt_install apt-transport-https curl gnupg2
# Remove any old plex repo files (plexmediaserver.list or plex.list from prior installs)
rm -f /etc/apt/sources.list.d/plex*.list /etc/apt/sources.list.d/plexmediaserver.list
# Download new v2 signing key and install to keyring
curl -L https://downloads.plex.tv/plex-keys/PlexSign.v2.key 2>>"${log}" | gpg --yes --dearmor -o /usr/share/keyrings/plexmediaserver.v2.gpg 2>>"${log}"
# Write new repo source entry pointing to repo.plex.tv
echo "deb [signed-by=/usr/share/keyrings/plexmediaserver.v2.gpg] https://repo.plex.tv/deb/ public main" > /etc/apt/sources.list.d/plex.list
echo_progress_done "Plex repository configured"

apt_update

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

touch /install/.plex.lock

echo_success "Plex installed"
