. /etc/swizzin/sources/functions/pyenv
. /etc/swizzin/sources/functions/utils

user=$(_get_master_username)
LIST='chromium xvfb par2 p7zip-full python3.11 python3-dev python3-setuptools python3-pip python3-venv python3.11-venv gnutls-bin'

add-apt-repository --yes ppa:deadsnakes/ppa
add-apt-repository --yes ppa:xtradeb/apps
apt_update
# sudo apt remove -y --purge snapd
apt_install $LIST
#apt_install python3.11 python3-pip python3-dev python3-venv

pyenv_install
pyenv_install_version 3.11.13 # As shipping on Windows/macOS.
pyenv_create_venv 3.11.13 /opt/.venv/flaresolverr
chown -R ${user}: /opt/.venv/flaresolverr
#python3_venv ${user} flaresolverr

echo_progress_start "Downloading and extracting flaresolverr"
mkdir -p /opt/flaresolverr
cd /opt/flaresolverr
git clone --depth 1 --branch v3.3.16 https://github.com/FlareSolverr/FlareSolverr
cd FlareSolverr
echo_progress_done

echo_progress_start "Installing pip requirements"

/opt/.venv/flaresolverr/bin/pip3.11 install --upgrade pip wheel >> "${log}" 2>&1
/opt/.venv/flaresolverr/bin/pip3.11 install -r /opt/flaresolverr/FlareSolverr/requirements.txt >> "${log}" 2>&1

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
ExecStart=/opt/.venv/flaresolverr/bin/python3.11 /opt/flaresolverr/FlareSolverr/src/flaresolverr.py
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
