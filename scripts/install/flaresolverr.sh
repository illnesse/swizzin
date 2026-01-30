. /etc/swizzin/sources/functions/pyenv
. /etc/swizzin/sources/functions/utils

user=$(_get_master_username)
LIST='xvfb par2 p7zip-full build-essential libffi-dev python3-dev python3-setuptools python3-pip gnutls-bin'

apt_update
apt_install $LIST


rm /usr/share/keyrings/google-chrome.gpg
wget -qO- https://dl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" \
| sudo tee /etc/apt/sources.list.d/google-chrome.list

apt_update
apt_install google-chrome-stable


python3 -m venv /opt/.venv/flaresolverr
source /opt/.venv/flaresolverr/bin/activate

echo_progress_start "Downloading and extracting flaresolverr"
mkdir -p /opt/flaresolverr
cd /opt/flaresolverr
git clone https://github.com/FlareSolverr/FlareSolverr
cd FlareSolverr
echo_progress_done

echo_progress_start "Installing pip requirements"

/opt/.venv/flaresolverr/bin/pip install -r /opt/flaresolverr/FlareSolverr/requirements.txt >> "${log}" 2>&1

echo_progress_done


_systemd() {
    echo_progress_start "Installing Systemd service"
    cat > /etc/systemd/system/flaresolverr.service << EOF
[Unit]
Description=FlareSolverr
After=network.target

[Service]
SyslogIdentifier=flaresolverr
Restart=always
RestartSec=5
Type=simple
User=root
Environment="LOG_LEVEL=info"
Environment="CAPTCHA_SOLVER=none"
WorkingDirectory=/opt/flaresolverr/FlareSolverr
ExecStart=/opt/.venv/flaresolverr/bin/python3 /opt/flaresolverr/FlareSolverr/src/flaresolverr.py
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
EOF
    echo_progress_done "Service installed"

    systemctl enable -q --now flaresolverr 2>&1 | tee -a $log
}

_systemd


touch "/install/.flaresolverr.lock"
echo_success "flaresolverr installed"

