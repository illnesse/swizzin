#!/bin/bash
#
# swizzin Copyright (C) 2020 swizzin.ltd
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
function _install() {
	# for output to dashboard
	echo "Installing NZBHydra ... " >> "${log}" 2>&1
	# for output to box
	#echo "Installing NZBHydra ... "
	warning=$(echo -e "[ \e[1;91mWARNING\e[0m ]")
	apt-get -y update > /dev/null 2>&1
	apt-get -y install git-core python-dev > /dev/null 2>&1
	##echo >> "${log}"  2>&1;
	echo "Cloning NZBHydra git ... " >> "${log}" 2>&1
	git clone -q https://github.com/theotherp/nzbhydra.git /home/${MASTER}/nzbhydra || {
		echo "GIT failed"
		exit 1
	}
	chown ${MASTER}:${MASTER} -R /home/${MASTER}/nzbhydra
	mkdir /home/${MASTER}/.nzbhydra
	chown ${MASTER}:${MASTER} -R /home/${MASTER}/.nzbhydra
}

function _services() {
	# for output to dashboard
	echo "Installing and enabling service ... " >> "${log}" 2>&1
	# for output to box
	echo "Installing and enabling service ... "

	cat > /etc/systemd/system/nzbhydra@.service << NZBH
[Unit]
Description=NZBHydra
Documentation=https://github.com/theotherp/nzbhydra
After=syslog.target network.target

[Service]
Type=forking
KillMode=control-group
User=%i
Group=%i
ExecStart=/usr/bin/python /home/%i/nzbhydra/nzbhydra.py --daemon --nobrowser --pidfile /home/%i/.nzbhydra/nzbhydra.pid --logfile /home/%i/.nzbhydra/nzbhydra.log --database /home/%i/.nzbhydra/nzbhydra.db --config /home/%i/.nzbhydra/settings.cfg
GuessMainPID=no
ExecStop=-/bin/kill -HUP
Restart=on-failure

[Install]
WantedBy=multi-user.target
NZBH

	mkdir -p /home/${MASTER}/.nzbhydra
	chown ${MASTER}:${MASTER} -R /home/${MASTER}/.nzbhydra
	systemctl enable nzbhydra@${MASTER} > /dev/null 2>&1
	systemctl start nzbhydra@${MASTER} > /dev/null 2>&1

	if [[ -f /install/.nginx.lock ]]; then
		sleep 30
		bash /usr/local/bin/swizzin/nginx/nzbhydra.sh
		service nginx reload
	fi

	touch /install/.nzbhydra.lock
	echo "nzbhydra installation complete. " >> "${log}" 2>&1
}

MASTER=$(cut -d: -f1 < /root/.master.info)
_install
_services
