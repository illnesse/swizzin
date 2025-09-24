#!/bin/bash

function isRoot() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
}

function tunAvailable() {
    if [ ! -e /dev/net/tun ]; then
        return 1
    fi
}

function checkOS() {
    if [[ -e /etc/debian_version ]]; then
        OS="debian"
        source /etc/os-release

        if [[ "$ID" == "debian" ]]; then
            if [[ ! $VERSION_ID =~ (8|9) ]]; then
                echo "⚠️ Your version of Debian is not supported."
                echo ""
                echo "However, if you're using Debian >= 9 or unstable/testing then you can continue."
                echo "Keep in mind they are not supported, though."
                echo ""
                until [[ $CONTINUE =~ (y|n) ]]; do
                    read -rp "Continue? [y/n]: " -e CONTINUE
                done
                if [[ "$CONTINUE" = "n" ]]; then
                    exit 1
                fi
            fi
        elif [[ "$ID" == "ubuntu" ]]; then
            OS="ubuntu"
            if [[ ! $VERSION_ID =~ (16.04|18.04) ]]; then
                echo "⚠️ Your version of Ubuntu is not supported."
                echo ""
                echo "However, if you're using Ubuntu > 17 or beta, then you can continue."
                echo "Keep in mind they are not supported, though."
                echo ""
                # until [[ $CONTINUE =~ (y|n) ]]; do
                #     read -rp "Continue? [y/n]: " -e CONTINUE
                # done
                # if [[ "$CONTINUE" = "n" ]]; then
                #     exit 1
                # fi
            fi
        fi
    elif [[ -e /etc/fedora-release ]]; then
        OS=fedora
    elif [[ -e /etc/centos-release ]]; then
        if ! grep -qs "^CentOS Linux release 7" /etc/centos-release; then
            echo "Your version of CentOS is not supported."
            echo "The script only support CentOS 7."
            echo ""
            unset CONTINUE
            until [[ $CONTINUE =~ (y|n) ]]; do
                read -rp "Continue anyway? [y/n]: " -e CONTINUE
            done
            if [[ "$CONTINUE" = "n" ]]; then
                echo "Ok, bye!"
                exit 1
            fi
        fi
        OS=centos
    elif [[ -e /etc/arch-release ]]; then
        OS=arch
    else
        echo "Looks like you aren't running this installer on a Debian, Ubuntu, Fedora, CentOS or Arch Linux system"
        exit 1
    fi
}

function initialCheck() {
    if ! isRoot; then
        echo "Sorry, you need to run this as root"
        exit 1
    fi
    if ! tunAvailable; then
        echo "TUN is not available"
        exit 1
    fi
    checkOS
}

function removeOpenVPN() {

    # Get OpenVPN port from the configuration
    PORT=$(grep '^port ' /etc/openvpn/server.conf | cut -d " " -f 2)

    # Stop OpenVPN
    if [[ "$OS" =~ (fedora|arch) ]]; then
        systemctl disable openvpn-server@server
        systemctl stop openvpn-server@server
        # Remove customised service
        rm /etc/systemd/system/openvpn-server@.service
    elif [[ "$OS" == "ubuntu" ]] && [[ "$VERSION_ID" == "16.04" ]]; then
        systemctl disable openvpn
        systemctl stop openvpn
    else
        systemctl disable openvpn@server
        systemctl stop openvpn@server
        # Remove customised service
        rm /etc/systemd/system/openvpn\@.service
    fi

    # Remove the iptables rules related to the script
    systemctl stop iptables-openvpn
    # Cleanup
    systemctl disable iptables-openvpn
    rm /etc/systemd/system/iptables-openvpn.service
    systemctl daemon-reload
    rm /etc/iptables/add-openvpn-rules.sh
    rm /etc/iptables/rm-openvpn-rules.sh

    # SELinux
    if hash sestatus 2> /dev/null; then
        if sestatus | grep "Current mode" | grep -qs "enforcing"; then
            if [[ "$PORT" != '1194' ]]; then
                semanage port -d -t openvpn_port_t -p udp "$PORT"
            fi
        fi
    fi

    if [[ "$OS" =~ (debian|ubuntu) ]]; then
        apt-get autoremove --purge -y openvpn
        if [[ -e /etc/apt/sources.list.d/openvpn.list ]]; then
            rm /etc/apt/sources.list.d/openvpn.list
            apt-get update
        fi
    elif [[ "$OS" = 'arch' ]]; then
        pacman --noconfirm -R openvpn
    elif [[ "$OS" = 'centos' ]]; then
        yum remove -y openvpn
    elif [[ "$OS" = 'fedora' ]]; then
        dnf remove -y openvpn
    fi

    # Cleanup
    find /home/ -maxdepth 2 -name "*.ovpn" -delete
    find /root/ -maxdepth 1 -name "*.ovpn" -delete
    rm -rf /etc/openvpn
    rm -rf /usr/share/doc/openvpn*
    rm -f /etc/sysctl.d/20-openvpn.conf
    rm -rf /var/log/openvpn

    # Unbound
    if [[ -e /etc/unbound/openvpn.conf ]]; then
        removeUnbound
    fi
    echo ""
    echo "OpenVPN removed!"
}

# Check for root, TUN, OS...
initialCheck

removeOpenVPN

rm /install/.openvpn2.lock
