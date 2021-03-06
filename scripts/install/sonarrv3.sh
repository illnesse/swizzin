#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

waitforapt
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF >>  "${SEEDIT_LOG}"  2>&1

waitforapt
apt -y install apt-transport-https ca-certificates >>  "${SEEDIT_LOG}"  2>&1

echo "deb https://download.mono-project.com/repo/ubuntu stable-xenial main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list >>  "${SEEDIT_LOG}"  2>&1

waitforapt
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 2009837CBFFD68F45BC180471F4F90DE2A9B4BF8 >>  "${SEEDIT_LOG}"  2>&1

echo "deb https://apt.sonarr.tv/ubuntu xenial main" | sudo tee /etc/apt/sources.list.d/sonarr.list >>  "${SEEDIT_LOG}"  2>&1

waitforapt
apt update

waitforapt
apt -y -f install sonarr >>  "${SEEDIT_LOG}"  2>&1
usermod -a -G seedit4me sonarr

systemctl stop sonarr

touch /install/.sonarrv3.lock

if [[ -f /install/.nginx.lock ]]; then
  bash /usr/local/bin/swizzin/nginx/sonarrv3.sh
  service nginx reload
fi