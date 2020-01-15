#!/bin/bash

function _uplounge () {
systemctl stop lounge
npm install -g thelounge@latest >> /dev/null 2>&1
sudo -u lounge bash -c "thelounge install thelounge-theme-zenburn" >> /dev/null 2>&1
    if [[ ! -d /home/lounge/.thelounge ]]; then
        mv /home/lounge/.lounge /home/lounge/.thelounge
        sed -i 's|theme: "zenburn"|theme: "thelounge-theme-zenburn"|g' /home/lounge/.thelounge/config.js
    fi
systemctl start lounge
}

if [[ -f /install/.lounge.sh ]]; then
    if grep -q "/usr/bin/lounge" /etc/systemd/system/lounge.service; then
        sed -i "s/ExecStart=\/usr\/bin\/lounge/ExecStart=\/usr\/bin\/thelounge/g" /etc/systemd/system/lounge.service
        systemctl daemon-reload
    fi

    if grep -q 'host: "irc.swizzin.ltd"' /home/lounge/.thelounge/config.js; then
        sed -i 's/host: "irc.swizzin.ltd",/host: "irc.seedit4.me",/g' /home/lounge/.thelounge/config.js
        sed -i 's/port: 6697,/port: 8010,/g' /home/lounge/.thelounge/config.js
        sed -i 's/name: "SwizzNet",/name: "Seedit4.me",/g' /home/lounge/.thelounge/config.js
        sed -i 's/nick: "swizzie",/nick: "user",/g' /home/lounge/.thelounge/config.js
        sed -i 's/username: "swizzie",/username: "user",/g' /home/lounge/.thelounge/config.js
        sed -i 's/realname: "swizzin",/realname: "_user",/g' /home/lounge/.thelounge/config.js
        sed -i 's/join: "#swizzin"/join: "#seedit4me"/g' /home/lounge/.thelounge/config.js
        echo "updated lounge with seedit4.me irc info"
    fi

    if grep -q 'bind: "127.0.0.1"' /home/lounge/.thelounge/config.js; then
        sed -i 's/bind: "127.0.0.1",/bind: undefined,/g' /home/lounge/.thelounge/config.js
        sed -i 's/host: undefined,/host: "127.0.0.1",/g' /home/lounge/.thelounge/config.js
        systemctl restart lounge
    fi

    if [[ $(thelounge -v) =~ "v2" ]]; then
        echo "There is an update for The Lounge. Do you wish to upgrade?"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) _uplounge; break;;
                No ) break;;
            esac
        done
    fi

fi


    