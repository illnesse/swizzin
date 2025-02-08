#!/bin/bash
#

#if [[ -f /install/.tools.lock ]]; then
#  log="/srv/tools/logs/output.log"
#else
#  log="/dev/null"
#fi
user=$(cut -d: -f1 < /root/.master.info)

echo_progress_start "Adding dependencies"
if [[ $codename =~ ("bionic"|"stretch"|"xenial") ]]; then
    #shellcheck source=sources/functions/pyenv
    . /etc/swizzin/sources/functions/pyenv
    pyenv_install
    pyenv_install_version 3.7.7
    pyenv_create_venv 3.7.7 /opt/.venv/lazylibrarian
    chown -R ${user}: /opt/.venv/lazylibrarian
else
    apt_install python3-pip python3-dev python3-venv
    mkdir -p /opt/.venv/lazylibrarian
    python3 -m venv /opt/.venv/lazylibrarian
    chown -R ${user}: /opt/.venv/lazylibrarian
fi
echo_progress_done "dependencies set up"

cd /opt

echo_progress_start "Cloning into '/opt/lazylibrarian'"
git clone https://gitlab.com/LazyLibrarian/LazyLibrarian.git lazylibrarian >> $log 2>&1
chown -R ${user}: lazylibrarian
echo_progress_done "cloned"
cd lazylibrarian

echo_progress_start "Checking python depends"
sudo -u ${user} bash -c "/opt/.venv/lazylibrarian/bin/pip3 install --upgrade pip" >> $log 2>&1
sudo -u ${user} bash -c "/opt/.venv/lazylibrarian/bin/pip3 install urllib3 apprise cryptography pyopenssl pillow pyparsing" >> $log 2>&1
echo_progress_done "Dependencies installed"


echo_progress_start "Enabling lazylibrarian Systemd configuration"
cat > /etc/systemd/system/lazylibrarian.service << SUBSD
[Unit]
Description=lazylibrarian for ${user}
After=syslog.target network.target

[Service]
WorkingDirectory=/opt/lazylibrarian
User=${user}
Group=${user}
UMask=0002
Restart=on-failure
RestartSec=5
Type=simple
ExecStart=/opt/.venv/lazylibrarian/bin/python3 /opt/lazylibrarian/LazyLibrarian.py
KillSignal=SIGINT
TimeoutStopSec=20
SyslogIdentifier=lazylibrarian.${user}

[Install]
WantedBy=multi-user.target
SUBSD

systemctl enable -q --now lazylibrarian 2>&1 | tee -a $log
echo_progress_done "service installed"

echo_progress_start "Setting up lazylibrarian nginx configuration"
bash /usr/local/bin/swizzin/nginx/lazylibrarian.sh
systemctl reload nginx
echo_progress_done

touch /install/.lazylibrarian.lock

echo_success "lazylibrarian installed"
