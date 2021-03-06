#! /bin/bash
# Medusa installer for swizzin
# Author: liara

#if [[ -f /tmp/.install.lock ]]; then
#  log="/root/logs/install.log"
#elif [[ -f /install/.panel.lock ]]; then
#  log="/srv/panel/db/output.log"
#else
#  log="/dev/null"
#fi
distribution=$(lsb_release -is)
user=$(cut -d: -f1 < /root/.master.info)

if [[ $(systemctl is-active sickgear@${user}) == "active" ]]; then
  active=sickgear
fi

if [[ $(systemctl is-active sickchill@${user}) == "active" ]]; then
  active=sickchill
fi

if [[ -n $active ]]; then
  echo "SickChill and Medusa and Sickgear cannot be active at the same time."
  echo "Do you want to disable $active and continue with the installation?"
  echo "Don't worry, your install will remain at /home/${user}/.$active"
  while true; do
  read -p "Do you want to disable $active? " yn
      case "$yn" in
          [Yy]|[Yy][Ee][Ss]) disable=yes; break;;
          [Nn]|[Nn][Oo]) disable=; break;;
          *) echo "Please answer yes or no.";;
      esac
  done
  if [[ $disable == "yes" ]]; then
    systemctl disable ${active}@${user}
    systemctl stop ${active}@${user}
  else
    exit 1
  fi
fi

#mkdir -p /opt/.venv
#chown ${user}: /opt/.venv

apt-get -y -q update >>  "${SEEDIT_LOG}"  2>&1
apt-get -y -q install git-core openssl libssl-dev python3 >>  "${SEEDIT_LOG}"  2>&1

function _rar () {
  cd /tmp
  wget -q http://www.rarlab.com/rar/rarlinux-x64-5.5.0.tar.gz
  tar -xzf rarlinux-x64-5.5.0.tar.gz >/dev/null 2>&1
  cp rar/*rar /bin >/dev/null 2>&1
  rm -rf rarlinux*.tar.gz >/dev/null 2>&1
  rm -rf /tmp/rar >/dev/null 2>&1
}

if [[ -z $(which rar) ]]; then
  apt-get -y install rar unrar >> "${SEEDIT_LOG}"  2>&1 || { echo "INFO: Could not find rar/unrar in the repositories. It is likely you do not have the multiverse repo enabled. Installing directly."; _rar; }
fi
cd /opt/
git clone  --branch v0.4.3 https://github.com/pymedusa/Medusa.git medusa >> ${SEEDIT_LOG} 2>&1
chown -R ${user}:${user} medusa

cat > /etc/systemd/system/medusa.service << MSD
[Unit]
Description=Medusa
After=syslog.target network.target

[Service]
Type=forking
GuessMainPID=no
User=${user}
Group=${user}
ExecStart=/usr/bin/python3 /opt/medusa/SickBeard.py -q --daemon --nolaunch --datadir=/opt/medusa
ExecStop=-/bin/kill -HUP


[Install]
WantedBy=multi-user.target
MSD

systemctl enable -q --now medusa  >> "${SEEDIT_LOG}"  2>&1

if [[ -f /install/.nginx.lock ]]; then
  bash /usr/local/bin/swizzin/nginx/medusa.sh
  systemctl reload nginx
fi

touch /install/.medusa.lock
