#!/bin/bash
user=$(cut -d: -f1 < /root/.master.info)
internalip=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')

app="rtorrent"
if [[ -f /install/.$app.lock ]]; then
  echo_info "updating ports for ${app}."
  systemctl stop rtorrent@${user}
  sleep 3
  port=$(cat /home/seedit4me/.rtorrent_port)
  portend=$(cat /home/seedit4me/.rtorrent_port)
  sed -i "s/network.port_range.set.*/network.port_range.set = ${port}-${portend}/g" /home/${user}/.rtorrent.rc
  systemctl restart rtorrent@${user}
  echo_success "${app} ports updated."
fi

app="transmission"
if [[ -f /install/.$app.lock ]]; then
  echo_info "updating ports for ${app}."
  systemctl stop transmission@${user}
  sleep 3
  port=$(cat /home/seedit4me/.transmission_port)
  sed -i "s/\"peer-port\":.*/\"peer-port\": ${port},/g" /home/${user}/.config/transmission-daemon/settings.json
  sed -i "s/\"peer-port-random-high\":.*/\"peer-port-random-high\": ${port},/g" /home/${user}/.config/transmission-daemon/settings.json
  sed -i "s/\"peer-port-random-low\":.*/\"peer-port-random-low\": ${port},/g" /home/${user}/.config/transmission-daemon/settings.json
  systemctl start transmission@${user}
  echo_success "${app} ports updated."
fi

app="qbittorrent"
if [[ -f /install/.$app.lock ]]; then
  echo_info "updating ports for ${app}."
  systemctl stop qbittorrent@${user}
  sleep 3
  port=$(cat /home/seedit4me/.qbittorrent_port)
  sed -i "s/Connection\\\PortRangeMin.*/Connection\\\PortRangeMin=${port}/g" /home/${user}/.config/qBittorrent/qBittorrent.conf
  systemctl start qbittorrent@${user}
  echo_success "${app} ports updated."
fi

app="btsync"
if [[ -f /install/.$app.lock ]]; then
  echo_info "updating ports for ${app}."
  systemctl stop resilio-sync
  sleep 3
  port=$(cat /home/seedit4me/.btsync_port)
  port2=$(cat /home/seedit4me/.btsync2_port)
  sed -i "s/\"listen\" : \"0.0.0.0:.*/\"listen\" : \"0.0.0.0:${port}\",/g" /etc/resilio-sync/config.json
  sed -i "s/\"listening_port\" : .*/\"listening_port\" : ${port2},/g" /etc/resilio-sync/config.json
  systemctl restart resilio-sync
  echo_success "${app} ports updated."
fi

app="deluge"
if [[ -f /install/.$app.lock ]]; then
  echo_info "updating ports for ${app}."
  systemctl stop deluged@${user}
  systemctl stop deluge-web@${user}
  sleep 3
  port=$(cat /home/seedit4me/.deluge_port)
  #thats some cryptic shit right there
  sed -i "s/\"listen_interface\": \"[^][]*\"/\"listen_interface\": \"${internalip}\"/g" /home/${user}/.config/deluge/core.conf
  sed -i -e '1h;2,$H;$!d;g' -e 's/\"port\": \[[^][]*\],/\"port\": \[\n'${port}',\n'${port}'\n\],\n/' /home/${user}/.config/deluge/core.conf
  sed -i -e '1h;2,$H;$!d;g' -e 's/\"listen_ports\": \[[^][]*\],/\"listen_ports\": \[\n'${port}',\n'${port}'\n\],\n/' /home/${user}/.config/deluge/core.conf
  systemctl start deluged@${user}
  systemctl start deluge-web@${user}
  echo_success "${app} ports updated."
fi

# plex just needs plexclaim.sh

app="plex"
if [[ -f /install/.$app.lock ]]; then
  echo_info "updating ports for ${app}."
  systemctl stop plexmediaserver
  sleep 3
  port=$(cat /home/seedit4me/.plex_port)
  home="$(echo ~plex)"
  pmsApplicationSupportDir="${PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR:-${home}/Library/Application Support}"
  prefFile="${pmsApplicationSupportDir}/Plex Media Server/Preferences.xml"
  key="ManualPortMappingPort"
  value="${port}"
  count="$(grep -c "${key}" "${prefFile}")"
  count=$(($count + 0))
  if [[ $count > 0 ]]; then
    sed -i -E "s/${key}=\"([^\"]*)\"/${key}=\"$value\"/" "${prefFile}"
  else
    sed -i -E "s/\/>/ ${key}=\"$value\"\/>/" "${prefFile}"
  fi
  systemctl restart plexmediaserver
  echo_success "${app} ports updated."
fi

app="quassel"
if [[ -f /install/.$app.lock ]]; then
  echo_info "updating ports for ${app}."
  systemctl stop quasselcore
  sleep 3
  port=$(cat /home/seedit4me/.quassel_port)
  sed -i -e 's/\"PORT=.*\" \"/\"PORT='${port}'"/g' /lib/systemd/system/quasselcore.service
  sed -i -e 's/\"PORT=.*\" \"/\"PORT='${port}'"/g' /etc/default/quasselcore
  systemctl daemon-reload
  systemctl restart quasselcore
  echo_success "${app} ports updated."
fi

app="znc"
if [[ -f /install/.$app.lock ]]; then
  echo_info "updating ports for ${app}."
  systemctl stop znc
  sleep 3
  port=$(cat /home/seedit4me/.znc_port)
  sed -i 's/Port =.*/Port = '${port}'/g' /home/znc/.znc/configs/znc.conf
  systemctl restart znc
  echo_success "${app} ports updated."
fi

app="proftpd"
if [[ -f /install/.$app.lock ]]; then
  echo_info "reinstalling ${app}."
  bash /etc/swizzin/scripts/box remove ${app} > /srv/tools/logs/test1.log 2>&1
  sleep 3
  bash /etc/swizzin/scripts/box install ${app}  > /srv/tools/logs/test2.log 2>&1
  echo_success "${app} reinstalled."
fi

app="vsftpd"
if [[ -f /install/.$app.lock ]]; then
  echo_info "reinstalling ${app}."
  bash /etc/swizzin/scripts/box remove ${app} > /srv/tools/logs/test1.log 2>&1
  sleep 3
  bash /etc/swizzin/scripts/box install ${app}  > /srv/tools/logs/test2.log 2>&1
  echo_success "${app} reinstalled."
fi

app="openvpn2"
if [[ -f /install/.$app.lock ]]; then
  echo_info "reinstalling ${app}."
  bash /etc/swizzin/scripts/box remove ${app} > /srv/tools/logs/test1.log 2>&1
  sleep 3
  bash /etc/swizzin/scripts/box install ${app}  > /srv/tools/logs/test2.log 2>&1
  echo_success "${app} reinstalled."
fi
