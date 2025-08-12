. /etc/swizzin/sources/functions/pyenv
. /etc/swizzin/sources/functions/utils

user=$(_get_master_username)
LIST='chromium xvfb par2 p7zip-full build-essential libffi-dev python3-dev python3-setuptools python3-pip python3-venv python3.11-venv gnutls-bin'

cat > /etc/apt/sources.list.d/debian.list << EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/debian-buster.gpg] http://archive.debian.org/debian buster main
deb [arch=amd64 signed-by=/usr/share/keyrings/debian-buster-updates.gpg] http://archive.debian.org/debian buster-updates main
deb [arch=amd64 signed-by=/usr/share/keyrings/debian-security-buster.gpg] http://archive.debian.org/debian-security buster/updates main
EOF

sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 112695A0E562B32A
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys DCC9EFBF77E11517
sudo apt-key export 77E11517 | sudo gpg --dearmour --yes -o /usr/share/keyrings/debian-buster.gpg
sudo apt-key export 22F3D138 | sudo gpg --dearmour --yes -o /usr/share/keyrings/debian-buster-updates.gpg
sudo apt-key export E562B32A | sudo gpg --dearmour --yes -o /usr/share/keyrings/debian-security-buster.gpg

cat > /etc/apt/preferences.d/chromium.pref << EOF
# Note: 2 blank lines are required between entries
Package: *
Pin: release a=eoan
Pin-Priority: 500

Package: *
Pin: origin "archive.debian.org"
Pin-Priority: 300

# Pattern includes 'chromium', 'chromium-browser' and similarly
# named dependencies:
Package: chromium*
Pin: origin "archive.debian.org"
Pin-Priority: 700
EOF

add-apt-repository --yes ppa:deadsnakes/ppa
apt_update
apt_install $LIST
#apt_install python3.11 python3-pip python3-dev python3-venv

# pyenv_install
# pyenv_install_version 3.11 # As shipping on Windows/macOS.
#pyenv_create_venv 3.11 /opt/.venv/flaresolverr
# python3_venv ${user} flaresolverr
# chown -R ${user}: /opt/.venv/flaresolverr
python3.11 -m venv /opt/.venv/flaresolverr
source /opt/.venv/flaresolverr/bin/activate

echo_progress_start "Downloading and extracting flaresolverr"
mkdir -p /opt/flaresolverr
cd /opt/flaresolverr
git clone --depth 1 --branch v3.3.16 https://github.com/FlareSolverr/FlareSolverr
cd FlareSolverr
echo_progress_done

echo_progress_start "Installing pip requirements"

# pip install -r requirements.txt
# /opt/.venv/flaresolverr/bin/pip install --upgrade pip wheel >> "${log}" 2>&1
/opt/.venv/flaresolverr/bin/pip install -r /opt/flaresolverr/FlareSolverr/requirements.txt >> "${log}" 2>&1

echo_progress_done



##############################

#mkdir -p /opt/.venv/flaresolverr
#python3.11 -m venv /opt/.venv/flaresolverr
#chown -R "${user}": /opt/.venv/flaresolverr

#. /etc/swizzin/sources/functions/pyenv
#pyenv_install
#pyenv_install_version 3.11
#pyenv_create_venv 3.11 /opt/.venv/flaresolverr
#chown -R "${user}": /opt/.venv/flaresolverr

#cd /opt/.venv/flaresolverr
#git clone https://github.com/FlareSolverr/FlareSolverr
#cd FlareSolverr

#/opt/.venv/flaresolverr/pip3 install -r /opt/.venv/flaresolverr/FlareSolverr/requirements.txt
#pip install -r requirements.txt

#wget https://github.com/FlareSolverr/FlareSolverr/releases/download/v3.1.1/flaresolverr_linux_x64.tar.gz
#tar xfz flaresolverr_linux_x64.tar.gz
#rm flaresolverr_linux_x64.tar.gz
# cd flaresolverr

#apt_install libgtk-3-0 libdbus-glib-1-2

# #shellcheck source=sources/functions/npm
# . /etc/swizzin/sources/functions/npm
# npm_install

# git clone https://github.com/FlareSolverr/FlareSolverr /opt/flaresolverr
# cd /opt/flaresolverr

# export PUPPETEER_PRODUCT=firefox
# npm install jest@^27.0.0
# npm install
# npm run-script package

# cp /opt/flaresolverr/bin/flaresolverr-linux /opt/flaresolverr/flaresolverr
# cp -r /opt/flaresolverr/bin/puppeteer/linux-*/firefox /opt/flaresolverr/firefox



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

