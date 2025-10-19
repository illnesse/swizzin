#!/bin/bash
# shellcheck disable=SC1091,SC2164,SC2034,SC1072,SC1073,SC1009

# Secure OpenVPN server installer for Debian, Ubuntu, CentOS, Amazon Linux 2, Fedora, Oracle Linux 8, Arch Linux, Rocky Linux and AlmaLinux.
# https://github.com/angristan/openvpn-install

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

        if [[ $ID == "debian" || $ID == "raspbian" ]]; then
            if [[ $VERSION_ID -lt 9 ]]; then
                echo "⚠️ Your version of Debian is not supported."
                echo ""
                echo "However, if you're using Debian >= 9 or unstable/testing, you can continue at your own risk."
                echo ""
                until [[ $CONTINUE =~ (y|n) ]]; do
                    read -rp "Continue? [y/n]: " -e CONTINUE
                done
                if [[ $CONTINUE == "n" ]]; then
                    exit 1
                fi
            fi
        elif [[ $ID == "ubuntu" ]]; then
            OS="ubuntu"
            MAJOR_UBUNTU_VERSION=$(echo "$VERSION_ID" | cut -d '.' -f1)
            if [[ $MAJOR_UBUNTU_VERSION -lt 16 ]]; then
                echo "⚠️ Your version of Ubuntu is not supported."
                echo ""
                echo "However, if you're using Ubuntu >= 16.04 or beta, you can continue at your own risk."
                echo ""
                until [[ $CONTINUE =~ (y|n) ]]; do
                    read -rp "Continue? [y/n]: " -e CONTINUE
                done
                if [[ $CONTINUE == "n" ]]; then
                    exit 1
                fi
            fi
        fi
    elif [[ -e /etc/system-release ]]; then
        source /etc/os-release
        if [[ $ID == "fedora" || $ID_LIKE == "fedora" ]]; then
            OS="fedora"
        fi
        if [[ $ID == "centos" || $ID == "rocky" || $ID == "almalinux" ]]; then
            OS="centos"
            if [[ ${VERSION_ID%.*} -lt 7 ]]; then
                echo "⚠️ Your version of CentOS is not supported."
                echo ""
                echo "The script only supports CentOS 7 and CentOS 8."
                echo ""
                exit 1
            fi
        fi
        if [[ $ID == "ol" ]]; then
            OS="oracle"
            if [[ ! $VERSION_ID =~ (8) ]]; then
                echo "Your version of Oracle Linux is not supported."
                echo ""
                echo "The script only supports Oracle Linux 8."
                exit 1
            fi
        fi
        if [[ $ID == "amzn" ]]; then
            if [[ $VERSION_ID == "2" ]]; then
                OS="amzn"
            elif [[ "$(echo "$PRETTY_NAME" | cut -c 1-18)" == "Amazon Linux 2023." ]] && [[ "$(echo "$PRETTY_NAME" | cut -c 19)" -ge 6 ]]; then
                OS="amzn2023"
            else
                echo "⚠️ Your version of Amazon Linux is not supported."
                echo ""
                echo "The script only supports Amazon Linux 2 or Amazon Linux 2023.6+"
                echo ""
                exit 1
            fi
        fi
    elif [[ -e /etc/arch-release ]]; then
        OS=arch
    else
        echo "It looks like you aren't running this installer on a Debian, Ubuntu, Fedora, CentOS, Amazon Linux 2, Oracle Linux 8 or Arch Linux system."
        exit 1
    fi
}

function initialCheck() {
    if ! isRoot; then
        echo "Sorry, you need to run this script as root."
        exit 1
    fi
    if ! tunAvailable; then
        echo "TUN is not available."
        exit 1
    fi
    checkOS
}

function installUnbound() {
    # If Unbound isn't installed, install it
    if [[ ! -e /etc/unbound/unbound.conf ]]; then
        echo_progress_start "Installing Unbound DNS resolver"

        if [[ $OS =~ (debian|ubuntu) ]]; then
            apt-get install -y unbound

            # Configuration
            echo 'interface: 10.8.0.1
access-control: 10.8.0.1/24 allow
hide-identity: yes
hide-version: yes
use-caps-for-id: yes
prefetch: yes' >>/etc/unbound/unbound.conf

        elif [[ $OS =~ (centos|amzn|oracle) ]]; then
            yum install -y unbound

            # Configuration
            sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
            sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
            sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
            sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
            sed -i 's|use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

        elif [[ $OS == "fedora" ]]; then
            dnf install -y unbound

            # Configuration
            sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
            sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
            sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
            sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
            sed -i 's|# use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

        elif [[ $OS == "arch" ]]; then
            pacman -Syu --noconfirm unbound

            # Get root servers list
            curl -o /etc/unbound/root.hints https://www.internic.net/domain/named.cache

            if [[ ! -f /etc/unbound/unbound.conf.old ]]; then
                mv /etc/unbound/unbound.conf /etc/unbound/unbound.conf.old
            fi

            echo 'server:
    use-syslog: yes
    do-daemonize: no
    username: "unbound"
    directory: "/etc/unbound"
    trust-anchor-file: trusted-key.key
    root-hints: root.hints
    interface: 10.8.0.1
    access-control: 10.8.0.1/24 allow
    port: 53
    num-threads: 2
    use-caps-for-id: yes
    harden-glue: yes
    hide-identity: yes
    hide-version: yes
    qname-minimisation: yes
    prefetch: yes' >/etc/unbound/unbound.conf
        fi

        # IPv6 DNS for all OS
        if [[ $IPV6_SUPPORT == 'y' ]]; then
            echo 'interface: fd42:42:42:42::1
access-control: fd42:42:42:42::/112 allow' >>/etc/unbound/unbound.conf
        fi

        if [[ ! $OS =~ (fedora|centos|amzn|oracle) ]]; then
            # DNS Rebinding fix
            echo "private-address: 10.0.0.0/8
private-address: fd42:42:42:42::/112
private-address: 172.16.0.0/12
private-address: 192.168.0.0/16
private-address: 169.254.0.0/16
private-address: fd00::/8
private-address: fe80::/10
private-address: 127.0.0.0/8
private-address: ::ffff:0:0/96" >>/etc/unbound/unbound.conf
        fi
    else # Unbound is already installed
        echo 'include: /etc/unbound/openvpn.conf' >>/etc/unbound/unbound.conf

        # Add Unbound 'server' for the OpenVPN subnet
        echo 'server:
interface: 10.8.0.1
access-control: 10.8.0.1/24 allow
hide-identity: yes
hide-version: yes
use-caps-for-id: yes
prefetch: yes
private-address: 10.0.0.0/8
private-address: fd42:42:42:42::/112
private-address: 172.16.0.0/12
private-address: 192.168.0.0/16
private-address: 169.254.0.0/16
private-address: fd00::/8
private-address: fe80::/10
private-address: 127.0.0.0/8
private-address: ::ffff:0:0/96' >/etc/unbound/openvpn.conf
        if [[ $IPV6_SUPPORT == 'y' ]]; then
            echo 'interface: fd42:42:42:42::1
access-control: fd42:42:42:42::/112 allow' >>/etc/unbound/openvpn.conf
        fi
    fi

    echo_progress_start "Enabling and starting Unbound service"
    systemctl enable unbound
    systemctl restart unbound
    echo_progress_done "Unbound configured"
}

function resolvePublicIP() {
    # IP version flags, we'll use as default the IPv4
    CURL_IP_VERSION_FLAG="-4"
    DIG_IP_VERSION_FLAG="-4"

    # Behind NAT, we'll default to the publicly reachable IPv4/IPv6.
    if [[ $IPV6_SUPPORT == "y" ]]; then
        CURL_IP_VERSION_FLAG=""
        DIG_IP_VERSION_FLAG="-6"
    fi

    # If there is no public ip yet, we'll try to solve it using: https://api.seeip.org
    if [[ -z $PUBLIC_IP ]]; then
        PUBLIC_IP=$(curl -f -m 5 -sS --retry 2 --retry-connrefused "$CURL_IP_VERSION_FLAG" https://api.seeip.org 2>/dev/null)
    fi

    # If there is no public ip yet, we'll try to solve it using: https://ifconfig.me
    if [[ -z $PUBLIC_IP ]]; then
        PUBLIC_IP=$(curl -f -m 5 -sS --retry 2 --retry-connrefused "$CURL_IP_VERSION_FLAG" https://ifconfig.me 2>/dev/null)
    fi

    # If there is no public ip yet, we'll try to solve it using: https://api.ipify.org
    if [[ -z $PUBLIC_IP ]]; then
        PUBLIC_IP=$(curl -f -m 5 -sS --retry 2 --retry-connrefused "$CURL_IP_VERSION_FLAG" https://api.ipify.org 2>/dev/null)
    fi

    # If there is no public ip yet, we'll try to solve it using: ns1.google.com
    if [[ -z $PUBLIC_IP ]]; then
        PUBLIC_IP=$(dig $DIG_IP_VERSION_FLAG TXT +short o-o.myaddr.l.google.com @ns1.google.com | tr -d '"')
    fi

    if [[ -z $PUBLIC_IP ]]; then
        echo >&2 echo "Couldn't solve the public IP"
        exit 1
    fi

    echo "$PUBLIC_IP"
}

function installQuestions() {

    # Detect public IPv4 address and pre-fill for the user
    IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
    PUBLICIP=$(curl -s http://ipv4.icanhazip.com)
    ENDPOINT=$PUBLICIP
    IPV6_SUPPORT="n"
    PORT="1194"
    PROTOCOL="tcp"
    DNS="3"
    CIPHER="AES-128-GCM"
    CERT_TYPE="1" # ECDSA
    CERT_CURVE="prime256v1"
    CC_CIPHER="TLS-ECDHE-ECDSA-WITH-AES-128-GCM-SHA256"
    DH_TYPE="1" # ECDH
    DH_CURVE="prime256v1"
    HMAC_ALG="SHA256"
    TLS_SIG="1" # tls-crypt
}

function installOpenVPN() {
    if [[ $AUTO_INSTALL == "y" ]]; then
        # Set default choices so that no questions will be asked.
        APPROVE_INSTALL=${APPROVE_INSTALL:-y}
        APPROVE_IP=${APPROVE_IP:-y}
        IPV6_SUPPORT=${IPV6_SUPPORT:-n}
        PORT_CHOICE=${PORT_CHOICE:-1}
        PROTOCOL_CHOICE=${PROTOCOL_CHOICE:-1}
        DNS=${DNS:-1}
        COMPRESSION_ENABLED=${COMPRESSION_ENABLED:-n}
        CUSTOMIZE_ENC=${CUSTOMIZE_ENC:-n}
        CLIENT=${CLIENT:-client}
        PASS=${PASS:-1}
        CONTINUE=${CONTINUE:-y}

        if [[ -z $ENDPOINT ]]; then
            ENDPOINT=$(resolvePublicIP)
        fi
    fi

    # Run setup questions first, and set other variables if auto-install
    installQuestions

    # Get the "public" interface from the default route
    NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
    if [[ -z $NIC ]] && [[ $IPV6_SUPPORT == 'y' ]]; then
        NIC=$(ip -6 route show default | sed -ne 's/^default .* dev \([^ ]*\) .*$/\1/p')
    fi

    # $NIC can not be empty for script rm-openvpn-rules.sh
    if [[ -z $NIC ]]; then
        echo
        echo "Could not detect public interface."
        echo "This needs for setup MASQUERADE."
        until [[ $CONTINUE =~ (y|n) ]]; do
            read -rp "Continue? [y/n]: " -e CONTINUE
        done
        if [[ $CONTINUE == "n" ]]; then
            exit 1
        fi
    fi

    # If OpenVPN isn't installed yet, install it. This script is more-or-less
    # idempotent on multiple runs, but will only install OpenVPN from upstream
    # the first time.
    if [[ ! -e /etc/openvpn/server.conf ]]; then
        echo_progress_start "Installing OpenVPN and dependencies"
        if [[ $OS =~ (debian|ubuntu) ]]; then
            apt-get update
            apt-get -y install ca-certificates gnupg
            # We add the OpenVPN repo to get the latest version.
            if [[ $VERSION_ID == "16.04" ]]; then
                echo "deb http://build.openvpn.net/debian/openvpn/stable xenial main" >/etc/apt/sources.list.d/openvpn.list
                wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
                apt-get update
            fi
            # Ubuntu > 16.04 and Debian > 8 have OpenVPN >= 2.4 without the need of a third party repository.
            apt-get install -y openvpn iptables openssl wget ca-certificates curl
        elif [[ $OS == 'centos' ]]; then
            yum install -y epel-release
            yum install -y openvpn iptables openssl wget ca-certificates curl tar 'policycoreutils-python*'
        elif [[ $OS == 'oracle' ]]; then
            yum install -y oracle-epel-release-el8
            yum-config-manager --enable ol8_developer_EPEL
            yum install -y openvpn iptables openssl wget ca-certificates curl tar policycoreutils-python-utils
        elif [[ $OS == 'amzn' ]]; then
            amazon-linux-extras install -y epel
            yum install -y openvpn iptables openssl wget ca-certificates curl
        elif [[ $OS == 'amzn2023' ]]; then
            dnf install -y openvpn iptables openssl wget ca-certificates
        elif [[ $OS == 'fedora' ]]; then
            dnf install -y openvpn iptables openssl wget ca-certificates curl policycoreutils-python-utils
        elif [[ $OS == 'arch' ]]; then
            # Install required dependencies and upgrade the system
            pacman --needed --noconfirm -Syu openvpn iptables openssl wget ca-certificates curl
        fi
        echo_progress_done "OpenVPN packages installed"
        # An old version of easy-rsa was available by default in some openvpn packages
        if [[ -d /etc/openvpn/easy-rsa/ ]]; then
            rm -rf /etc/openvpn/easy-rsa/
        fi
    fi

    # Find out if the machine uses nogroup or nobody for the permissionless group
    if grep -qs "^nogroup:" /etc/group; then
        NOGROUP=nogroup
    else
        NOGROUP=nobody
    fi

    # Install the latest version of easy-rsa from source, if not already installed.
    if [[ ! -d /etc/openvpn/easy-rsa/ ]]; then
        echo_progress_start "Installing easy-rsa"
        local version="3.1.2"
        wget -O ~/easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${version}/EasyRSA-${version}.tgz
        mkdir -p /etc/openvpn/easy-rsa
        tar xzf ~/easy-rsa.tgz --strip-components=1 --no-same-owner --directory /etc/openvpn/easy-rsa
        rm -f ~/easy-rsa.tgz

        cd /etc/openvpn/easy-rsa/ || return
        case $CERT_TYPE in
        1)
            echo "set_var EASYRSA_ALGO ec" >vars
            echo "set_var EASYRSA_CURVE $CERT_CURVE" >>vars
            ;;
        2)
            echo "set_var EASYRSA_KEY_SIZE $RSA_KEY_SIZE" >vars
            ;;
        esac

        # Generate a random, alphanumeric identifier of 16 characters for CN and one for server name
        SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
        echo "$SERVER_CN" >SERVER_CN_GENERATED
        SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
        echo "$SERVER_NAME" >SERVER_NAME_GENERATED

        echo_progress_start "Generating PKI and certificates"
        # Create the PKI, set up the CA, the DH params and the server certificate
        ./easyrsa init-pki
        EASYRSA_CA_EXPIRE=3650 ./easyrsa --batch --req-cn="$SERVER_CN" build-ca nopass

        if [[ $DH_TYPE == "2" ]]; then
            # ECDH keys are generated on-the-fly so we don't need to generate them beforehand
            openssl dhparam -out dh.pem $DH_KEY_SIZE
        fi

        EASYRSA_CERT_EXPIRE=3650 ./easyrsa --batch build-server-full "$SERVER_NAME" nopass
        EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl

        case $TLS_SIG in
        1)
            # Generate tls-crypt key
            openvpn --genkey --secret /etc/openvpn/tls-crypt.key
            ;;
        2)
            # Generate tls-auth key
            openvpn --genkey --secret /etc/openvpn/tls-auth.key
            ;;
        esac
        echo_progress_done "PKI and certificates generated"
    else
        # If easy-rsa is already installed, grab the generated SERVER_NAME
        # for client configs
        cd /etc/openvpn/easy-rsa/ || return
        SERVER_NAME=$(cat SERVER_NAME_GENERATED)
    fi

    # Move all the generated files
    cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn
    if [[ $DH_TYPE == "2" ]]; then
        cp dh.pem /etc/openvpn
    fi

    # Make cert revocation list readable for non-root
    chmod 644 /etc/openvpn/crl.pem

    echo_progress_start "Generating server configuration"
    # Generate server.conf
    echo "port $PORT" >/etc/openvpn/server.conf
    if [[ $IPV6_SUPPORT == 'n' ]]; then
        echo "proto $PROTOCOL" >>/etc/openvpn/server.conf
    elif [[ $IPV6_SUPPORT == 'y' ]]; then
        echo "proto ${PROTOCOL}6" >>/etc/openvpn/server.conf
    fi

    echo "dev tun
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" >>/etc/openvpn/server.conf

    # DNS resolvers
    case $DNS in
    1) # Current system resolvers
        # Locate the proper resolv.conf
        # Needed for systems running systemd-resolved
        if grep -q "127.0.0.53" "/etc/resolv.conf"; then
            RESOLVCONF='/run/systemd/resolve/resolv.conf'
        else
            RESOLVCONF='/etc/resolv.conf'
        fi
        # Obtain the resolvers from resolv.conf and use them for OpenVPN
        sed -ne 's/^nameserver[[:space:]]\+\([^[:space:]]\+\).*$/\1/p' $RESOLVCONF | while read -r line; do
            # Copy, if it's a IPv4 |or| if IPv6 is enabled, IPv4/IPv6 does not matter
            if [[ $line =~ ^[0-9.]*$ ]] || [[ $IPV6_SUPPORT == 'y' ]]; then
                echo "push \"dhcp-option DNS $line\"" >>/etc/openvpn/server.conf
            fi
        done
        ;;
    2) # Self-hosted DNS resolver (Unbound)
        echo 'push "dhcp-option DNS 10.8.0.1"' >>/etc/openvpn/server.conf
        if [[ $IPV6_SUPPORT == 'y' ]]; then
            echo 'push "dhcp-option DNS fd42:42:42:42::1"' >>/etc/openvpn/server.conf
        fi
        ;;
    3) # Cloudflare
        echo 'push "dhcp-option DNS 1.0.0.1"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 1.1.1.1"' >>/etc/openvpn/server.conf
        ;;
    4) # Quad9
        echo 'push "dhcp-option DNS 9.9.9.9"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 149.112.112.112"' >>/etc/openvpn/server.conf
        ;;
    5) # Quad9 uncensored
        echo 'push "dhcp-option DNS 9.9.9.10"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 149.112.112.10"' >>/etc/openvpn/server.conf
        ;;
    6) # FDN
        echo 'push "dhcp-option DNS 80.67.169.40"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 80.67.169.12"' >>/etc/openvpn/server.conf
        ;;
    7) # DNS.WATCH
        echo 'push "dhcp-option DNS 84.200.69.80"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 84.200.70.40"' >>/etc/openvpn/server.conf
        ;;
    8) # OpenDNS
        echo 'push "dhcp-option DNS 208.67.222.222"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 208.67.220.220"' >>/etc/openvpn/server.conf
        ;;
    9) # Google
        echo 'push "dhcp-option DNS 8.8.8.8"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 8.8.4.4"' >>/etc/openvpn/server.conf
        ;;
    10) # Yandex Basic
        echo 'push "dhcp-option DNS 77.88.8.8"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 77.88.8.1"' >>/etc/openvpn/server.conf
        ;;
    11) # AdGuard DNS
        echo 'push "dhcp-option DNS 94.140.14.14"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 94.140.15.15"' >>/etc/openvpn/server.conf
        ;;
    12) # NextDNS
        echo 'push "dhcp-option DNS 45.90.28.167"' >>/etc/openvpn/server.conf
        echo 'push "dhcp-option DNS 45.90.30.167"' >>/etc/openvpn/server.conf
        ;;
    13) # Custom DNS
        echo "push \"dhcp-option DNS $DNS1\"" >>/etc/openvpn/server.conf
        if [[ $DNS2 != "" ]]; then
            echo "push \"dhcp-option DNS $DNS2\"" >>/etc/openvpn/server.conf
        fi
        ;;
    esac
    echo 'push "redirect-gateway def1 bypass-dhcp"' >>/etc/openvpn/server.conf

    # IPv6 network settings if needed
    if [[ $IPV6_SUPPORT == 'y' ]]; then
        echo 'server-ipv6 fd42:42:42:42::/112
tun-ipv6
push tun-ipv6
push "route-ipv6 2000::/3"
push "redirect-gateway ipv6"' >>/etc/openvpn/server.conf
    fi

    if [[ $COMPRESSION_ENABLED == "y" ]]; then
        echo "compress $COMPRESSION_ALG" >>/etc/openvpn/server.conf
    fi

    if [[ $DH_TYPE == "1" ]]; then
        echo "dh none" >>/etc/openvpn/server.conf
        echo "ecdh-curve $DH_CURVE" >>/etc/openvpn/server.conf
    elif [[ $DH_TYPE == "2" ]]; then
        echo "dh dh.pem" >>/etc/openvpn/server.conf
    fi

    case $TLS_SIG in
    1)
        echo "tls-crypt tls-crypt.key" >>/etc/openvpn/server.conf
        ;;
    2)
        echo "tls-auth tls-auth.key 0" >>/etc/openvpn/server.conf
        ;;
    esac

    echo "crl-verify crl.pem
ca ca.crt
cert $SERVER_NAME.crt
key $SERVER_NAME.key
auth $HMAC_ALG
cipher $CIPHER
ncp-ciphers $CIPHER
tls-server
tls-version-min 1.2
tls-cipher $CC_CIPHER
client-config-dir /etc/openvpn/ccd
status /var/log/openvpn/status.log
verb 3" >>/etc/openvpn/server.conf

    # Create client-config-dir dir
    mkdir -p /etc/openvpn/ccd
    # Create log dir
    mkdir -p /var/log/openvpn

    # Enable routing
    echo 'net.ipv4.ip_forward=1' >/etc/sysctl.d/99-openvpn.conf
    if [[ $IPV6_SUPPORT == 'y' ]]; then
        echo 'net.ipv6.conf.all.forwarding=1' >>/etc/sysctl.d/99-openvpn.conf
    fi
    # Apply sysctl rules
    sysctl --system
    echo_progress_done "Server configuration created"

    # If SELinux is enabled and a custom port was selected, we need this
    if hash sestatus 2>/dev/null; then
        if sestatus | grep "Current mode" | grep -qs "enforcing"; then
            if [[ $PORT != '1194' ]]; then
                semanage port -a -t openvpn_port_t -p "$PROTOCOL" "$PORT"
            fi
        fi
    fi

    echo_progress_start "Enabling and starting OpenVPN service"
    # Finally, restart and enable OpenVPN
    if [[ $OS == 'arch' || $OS == 'fedora' || $OS == 'centos' || $OS == 'oracle' || $OS == 'amzn2023' ]]; then
        # Don't modify package-provided service
        cp /usr/lib/systemd/system/openvpn-server@.service /etc/systemd/system/openvpn-server@.service

        # Workaround to fix OpenVPN service on OpenVZ
        sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn-server@.service
        # Another workaround to keep using /etc/openvpn/
        sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn-server@.service

        systemctl daemon-reload
        systemctl enable openvpn-server@server
        systemctl restart openvpn-server@server
    elif [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
        # On Ubuntu 16.04, we use the package from the OpenVPN repo
        # This package uses a sysvinit service
        systemctl enable openvpn
        systemctl start openvpn
    else
        # Don't modify package-provided service
        cp /lib/systemd/system/openvpn\@.service /etc/systemd/system/openvpn\@.service

        # Workaround to fix OpenVPN service on OpenVZ
        sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn\@.service
        # Another workaround to keep using /etc/openvpn/
        sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn\@.service

        systemctl daemon-reload
        systemctl enable openvpn@server
        systemctl restart openvpn@server
    fi
    echo_progress_done "OpenVPN service started"

    if [[ $DNS == 2 ]]; then
        installUnbound
    fi

    echo_progress_start "Configuring iptables rules"
    # Add iptables rules in two scripts
    mkdir -p /etc/iptables

    # Script to add rules
    echo "#!/bin/sh
iptables -t nat -I POSTROUTING 1 -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -I INPUT 1 -i tun0 -j ACCEPT
iptables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
iptables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT
iptables -I INPUT 1 -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >/etc/iptables/add-openvpn-rules.sh

    if [[ $IPV6_SUPPORT == 'y' ]]; then
        echo "ip6tables -t nat -I POSTROUTING 1 -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -I INPUT 1 -i tun0 -j ACCEPT
ip6tables -I FORWARD 1 -i $NIC -o tun0 -j ACCEPT
ip6tables -I FORWARD 1 -i tun0 -o $NIC -j ACCEPT
ip6tables -I INPUT 1 -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >>/etc/iptables/add-openvpn-rules.sh
    fi

    # Script to remove rules
    echo "#!/bin/sh
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -D INPUT -i tun0 -j ACCEPT
iptables -D FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -D FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >/etc/iptables/rm-openvpn-rules.sh

    if [[ $IPV6_SUPPORT == 'y' ]]; then
        echo "ip6tables -t nat -D POSTROUTING -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -D INPUT -i tun0 -j ACCEPT
ip6tables -D FORWARD -i $NIC -o tun0 -j ACCEPT
ip6tables -D FORWARD -i tun0 -o $NIC -j ACCEPT
ip6tables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" >>/etc/iptables/rm-openvpn-rules.sh
    fi

    chmod +x /etc/iptables/add-openvpn-rules.sh
    chmod +x /etc/iptables/rm-openvpn-rules.sh

    # Handle the rules via a systemd script
    echo "[Unit]
Description=iptables rules for OpenVPN
Before=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/iptables/add-openvpn-rules.sh
ExecStop=/etc/iptables/rm-openvpn-rules.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target" >/etc/systemd/system/iptables-openvpn.service

    # Enable service and apply rules
    systemctl daemon-reload
    systemctl enable iptables-openvpn
    systemctl start iptables-openvpn
    echo_progress_done "Iptables rules configured"

    # If the server is behind a NAT, use the correct IP address for the clients to connect to
    if [[ $ENDPOINT != "" ]]; then
        IP=$ENDPOINT
    fi

    # client-template.txt is created so we have a template to add further users later
    echo "client" >/etc/openvpn/client-template.txt
    if [[ $PROTOCOL == 'udp' ]]; then
        echo "proto udp" >>/etc/openvpn/client-template.txt
        echo "explicit-exit-notify" >>/etc/openvpn/client-template.txt
    elif [[ $PROTOCOL == 'tcp' ]]; then
        echo "proto tcp-client" >>/etc/openvpn/client-template.txt
    fi
    echo "remote $IP $PORT
dev tun
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name $SERVER_NAME name
auth $HMAC_ALG
auth-nocache
cipher $CIPHER
tls-client
tls-version-min 1.2
tls-cipher $CC_CIPHER
ignore-unknown-option block-outside-dns
setenv opt block-outside-dns # Prevent Windows 10 DNS leak
verb 3" >>/etc/openvpn/client-template.txt

    if [[ $COMPRESSION_ENABLED == "y" ]]; then
        echo "compress $COMPRESSION_ALG" >>/etc/openvpn/client-template.txt
    fi

    echo_progress_start "Generating client configurations"
    # Generate the custom client.ovpn
    CLIENT="seedit4me-user1"
    newClient
    CLIENT="seedit4me-user2"
    newClient
    CLIENT="seedit4me-user3"
    newClient
    CLIENT="seedit4me-user4"
    newClient
    CLIENT="seedit4me-user5"
    newClient
    echo_progress_done "Client configurations created"
    echo_info "If you want to add more clients, you simply need to run this script another time!"
}

function newClient() {
    echo ""
    echo "Tell me a name for the client."
    echo "The name must consist of alphanumeric character. It may also include an underscore or a dash."

    until [[ $CLIENT =~ ^[a-zA-Z0-9_-]+$ ]]; do
        read -rp "Client name: " -e CLIENT
    done

    echo ""
    echo "Do you want to protect the configuration file with a password?"
    echo "(e.g. encrypt the private key with a password)"
    echo "   1) Add a passwordless client"
    echo "   2) Use a password for the client"

    until [[ $PASS =~ ^[1-2]$ ]]; do
        read -rp "Select an option [1-2]: " -e -i 1 PASS
    done

    CLIENTEXISTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c -E "/CN=$CLIENT\$")
    if [[ $CLIENTEXISTS == '1' ]]; then
        echo ""
        echo "The specified client CN was already found in easy-rsa, please choose another name."
        exit
    else
        cd /etc/openvpn/easy-rsa/ || return
        case $PASS in
        1)
            EASYRSA_CERT_EXPIRE=3650 ./easyrsa --batch build-client-full "$CLIENT" nopass
            ;;
        2)
            echo "⚠️ You will be asked for the client password below ⚠️"
            EASYRSA_CERT_EXPIRE=3650 ./easyrsa --batch build-client-full "$CLIENT"
            ;;
        esac
        echo_info "Client $CLIENT added"
    fi

    # Home directory of the user, where the client configuration (.ovpn) will be written
    #	if [ -e "/home/seedit4me" ]; then  # if $1 is a user name
    #		homeDir="/home/$CLIENT"
    #	elif [ "${SUDO_USER}" ]; then   # if not, use SUDO_USER
    #		homeDir="/home/${SUDO_USER}"
    #	else  # if not SUDO_USER, use /root
    #		homeDir="/root"
    #	fi
    homeDir="/home/seedit4me"

    # Determine if we use tls-auth or tls-crypt
    if grep -qs "^tls-crypt" /etc/openvpn/server.conf; then
        TLS_SIG="1"
    elif grep -qs "^tls-auth" /etc/openvpn/server.conf; then
        TLS_SIG="2"
    fi

    # Generates the custom client.ovpn
    cp /etc/openvpn/client-template.txt "$homeDir/$CLIENT.ovpn"
    {
        echo "<ca>"
        cat "/etc/openvpn/easy-rsa/pki/ca.crt"
        echo "</ca>"

        echo "<cert>"
        awk '/BEGIN/,/END CERTIFICATE/' "/etc/openvpn/easy-rsa/pki/issued/$CLIENT.crt"
        echo "</cert>"

        echo "<key>"
        cat "/etc/openvpn/easy-rsa/pki/private/$CLIENT.key"
        echo "</key>"

        case $TLS_SIG in
        1)
            echo "<tls-crypt>"
            cat /etc/openvpn/tls-crypt.key
            echo "</tls-crypt>"
            ;;
        2)
            echo "key-direction 1"
            echo "<tls-auth>"
            cat /etc/openvpn/tls-auth.key
            echo "</tls-auth>"
            ;;
        esac
    } >>"$homeDir/$CLIENT.ovpn"

    echo ""
    echo "The configuration file has been written to $homeDir/$CLIENT.ovpn."
    echo "Download the .ovpn file and import it in your OpenVPN client."

    exit 0
}

function revokeClient() {
    NUMBEROFCLIENTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
    if [[ $NUMBEROFCLIENTS == '0' ]]; then
        echo ""
        echo "You have no existing clients!"
        exit 1
    fi

    echo ""
    echo "Select the existing client certificate you want to revoke"
    tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
    until [[ $CLIENTNUMBER -ge 1 && $CLIENTNUMBER -le $NUMBEROFCLIENTS ]]; do
        if [[ $CLIENTNUMBER == '1' ]]; then
            read -rp "Select one client [1]: " CLIENTNUMBER
        else
            read -rp "Select one client [1-$NUMBEROFCLIENTS]: " CLIENTNUMBER
        fi
    done
    CLIENT=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
    cd /etc/openvpn/easy-rsa/ || return
    ./easyrsa --batch revoke "$CLIENT"
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
    rm -f /etc/openvpn/crl.pem
    cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
    chmod 644 /etc/openvpn/crl.pem
    find /home/ -maxdepth 2 -name "$CLIENT.ovpn" -delete
    rm -f "/root/$CLIENT.ovpn"
    sed -i "/^$CLIENT,.*/d" /etc/openvpn/ipp.txt
    cp /etc/openvpn/easy-rsa/pki/index.txt{,.bk}

    echo ""
    echo "Certificate for client $CLIENT revoked."
}

function removeUnbound() {
    # Remove OpenVPN-related config
    sed -i '/include: \/etc\/unbound\/openvpn.conf/d' /etc/unbound/unbound.conf
    rm /etc/unbound/openvpn.conf

    until [[ $REMOVE_UNBOUND =~ (y|n) ]]; do
        echo ""
        echo "If you were already using Unbound before installing OpenVPN, I removed the configuration related to OpenVPN."
        read -rp "Do you want to completely remove Unbound? [y/n]: " -e REMOVE_UNBOUND
    done

    if [[ $REMOVE_UNBOUND == 'y' ]]; then
        # Stop Unbound
        systemctl stop unbound

        if [[ $OS =~ (debian|ubuntu) ]]; then
            apt-get remove --purge -y unbound
        elif [[ $OS == 'arch' ]]; then
            pacman --noconfirm -R unbound
        elif [[ $OS =~ (centos|amzn|oracle) ]]; then
            yum remove -y unbound
        elif [[ $OS == 'fedora' ]]; then
            dnf remove -y unbound
        fi

        rm -rf /etc/unbound/

        echo ""
        echo "Unbound removed!"
    else
        systemctl restart unbound
        echo ""
        echo "Unbound wasn't removed."
    fi
}

function removeOpenVPN() {
    echo ""
    read -rp "Do you really want to remove OpenVPN? [y/n]: " -e -i n REMOVE
    if [[ $REMOVE == 'y' ]]; then
        # Get OpenVPN port from the configuration
        PORT=$(grep '^port ' /etc/openvpn/server.conf | cut -d " " -f 2)
        PROTOCOL=$(grep '^proto ' /etc/openvpn/server.conf | cut -d " " -f 2)

        # Stop OpenVPN
        if [[ $OS =~ (fedora|arch|centos|oracle) ]]; then
            systemctl disable openvpn-server@server
            systemctl stop openvpn-server@server
            # Remove customised service
            rm /etc/systemd/system/openvpn-server@.service
        elif [[ $OS == "ubuntu" ]] && [[ $VERSION_ID == "16.04" ]]; then
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
        if hash sestatus 2>/dev/null; then
            if sestatus | grep "Current mode" | grep -qs "enforcing"; then
                if [[ $PORT != '1194' ]]; then
                    semanage port -d -t openvpn_port_t -p "$PROTOCOL" "$PORT"
                fi
            fi
        fi

        if [[ $OS =~ (debian|ubuntu) ]]; then
            apt-get remove --purge -y openvpn
            if [[ -e /etc/apt/sources.list.d/openvpn.list ]]; then
                rm /etc/apt/sources.list.d/openvpn.list
                apt-get update
            fi
        elif [[ $OS == 'arch' ]]; then
            pacman --noconfirm -R openvpn
        elif [[ $OS =~ (centos|amzn|oracle) ]]; then
            yum remove -y openvpn
        elif [[ $OS == 'fedora' ]]; then
            dnf remove -y openvpn
        fi

        # Cleanup
        find /home/ -maxdepth 2 -name "*.ovpn" -delete
        find /root/ -maxdepth 1 -name "*.ovpn" -delete
        rm -rf /etc/openvpn
        rm -rf /usr/share/doc/openvpn*
        rm -f /etc/sysctl.d/99-openvpn.conf
        rm -rf /var/log/openvpn

        # Unbound
        if [[ -e /etc/unbound/openvpn.conf ]]; then
            removeUnbound
        fi
        echo ""
        echo "OpenVPN removed!"
    else
        echo ""
        echo "Removal aborted!"
    fi
}

function manageMenu() {
    echo "Welcome to OpenVPN-install!"
    echo "The git repository is available at: https://github.com/angristan/openvpn-install"
    echo ""
    echo "It looks like OpenVPN is already installed."
    echo ""
    echo "What do you want to do?"
    echo "   1) Add a new user"
    echo "   2) Revoke existing user"
    echo "   3) Remove OpenVPN"
    echo "   4) Exit"
    until [[ $MENU_OPTION =~ ^[1-4]$ ]]; do
        read -rp "Select an option [1-4]: " MENU_OPTION
    done

    case $MENU_OPTION in
    1)
        newClient
        ;;
    2)
        revokeClient
        ;;
    3)
        removeOpenVPN
        ;;
    4)
        exit 0
        ;;
    esac
}

# Check for root, TUN, OS...
initialCheck

# Check if OpenVPN is already installed
if [[ -e /etc/openvpn/server.conf && $AUTO_INSTALL != "y" ]]; then
    manageMenu
else
    installOpenVPN
fi

touch /install/.openvpn2.lock
echo_success "OpenVPN2 installed"
echo_info "Client configuration files have been created in /home/seedit4me/"
