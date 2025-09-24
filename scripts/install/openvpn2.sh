#!/bin/bash

# Secure OpenVPN server installer for Debian, Ubuntu, CentOS, Fedora and Arch Linux
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

function installUnbound() {
    if [[ ! -e /etc/unbound/unbound.conf ]]; then

        if [[ "$OS" =~ (debian|ubuntu) ]]; then
            apt_install unbound

            # Configuration
            echo 'interface: 10.8.0.1
access-control: 10.8.0.1/24 allow
hide-identity: yes
hide-version: yes
use-caps-for-id: yes
prefetch: yes' >> /etc/unbound/unbound.conf

        elif [[ "$OS" = "centos" ]]; then
            yum install -y unbound

            # Configuration
            sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
            sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
            sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
            sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
            sed -i 's|use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

        elif [[ "$OS" = "fedora" ]]; then
            dnf install -y unbound

            # Configuration
            sed -i 's|# interface: 0.0.0.0$|interface: 10.8.0.1|' /etc/unbound/unbound.conf
            sed -i 's|# access-control: 127.0.0.0/8 allow|access-control: 10.8.0.1/24 allow|' /etc/unbound/unbound.conf
            sed -i 's|# hide-identity: no|hide-identity: yes|' /etc/unbound/unbound.conf
            sed -i 's|# hide-version: no|hide-version: yes|' /etc/unbound/unbound.conf
            sed -i 's|# use-caps-for-id: no|use-caps-for-id: yes|' /etc/unbound/unbound.conf

        elif [[ "$OS" = "arch" ]]; then
            pacman -Syu --noconfirm unbound

            # Get root servers list
            curl -o /etc/unbound/root.hints https://www.internic.net/domain/named.cache

            mv /etc/unbound/unbound.conf /etc/unbound/unbound.conf.old

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
	prefetch: yes' > /etc/unbound/unbound.conf
        fi

        if [[ ! "$OS" =~ (fedora|centos) ]]; then
            # DNS Rebinding fix
            echo "private-address: 10.0.0.0/8
private-address: 172.16.0.0/12
private-address: 192.168.0.0/16
private-address: 169.254.0.0/16
private-address: fd00::/8
private-address: fe80::/10
private-address: 127.0.0.0/8
private-address: ::ffff:0:0/96" >> /etc/unbound/unbound.conf
        fi
    else # Unbound is already installed
        echo 'include: /etc/unbound/openvpn.conf' >> /etc/unbound/unbound.conf

        # Add Unbound 'server' for the OpenVPN subnet
        echo 'server:
interface: 10.8.0.1
access-control: 10.8.0.1/24 allow
hide-identity: yes
hide-version: yes
use-caps-for-id: yes
prefetch: yes
private-address: 10.0.0.0/8
private-address: 172.16.0.0/12
private-address: 192.168.0.0/16
private-address: 169.254.0.0/16
private-address: fd00::/8
private-address: fe80::/10
private-address: 127.0.0.0/8
private-address: ::ffff:0:0/96' > /etc/unbound/openvpn.conf
    fi

    systemctl enable unbound
    systemctl restart unbound
}

function installQuestions() {
    # Detect public IPv4 address and pre-fill for the user
    IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
    PUBLICIP=$(curl -s http://ipv4.icanhazip.com)
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
    # Run setup questions first
    installQuestions

    # Get the "public" interface from the default route
    NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)

    if [[ "$OS" =~ (debian|ubuntu) ]]; then
        apt_install ca-certificates gnupg
        # We add the OpenVPN repo to get the latest version.
        if [[ "$VERSION_ID" = "8" ]]; then
            echo "deb http://build.openvpn.net/debian/openvpn/stable jessie main" > /etc/apt/sources.list.d/openvpn.list
            wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
            apt-get update
        fi
        if [[ "$VERSION_ID" = "16.04" ]]; then
            echo "deb http://build.openvpn.net/debian/openvpn/stable trusty main" > /etc/apt/sources.list.d/openvpn.list
            wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
            apt-get update
        fi
        # Ubuntu > 16.04 and Debian > 8 have OpenVPN >= 2.4 without the need of a third party repository.
        apt_install openvpn iptables openssl wget ca-certificates curl
    elif [[ "$OS" = 'centos' ]]; then
        yum install -y epel-release
        yum install -y openvpn iptables openssl wget ca-certificates curl
    elif [[ "$OS" = 'fedora' ]]; then
        dnf install -y openvpn iptables openssl wget ca-certificates curl
    elif [[ "$OS" = 'arch' ]]; then
        echo ""
        echo "WARNING: As you're using ArchLinux, I need to update the packages on your system to install those I need."
        echo "Not doing that could cause problems between dependencies, or missing files in repositories (Arch Linux does not support partial upgrades)."
        echo ""
        echo "Continuing will update your installed packages and install needed ones."
        echo ""

        # Install required dependencies and upgrade the system
        pacman --needed --noconfirm -Syu openvpn iptables openssl wget ca-certificates curl
    fi

    # Find out if the machine uses nogroup or nobody for the permissionless group
    if grep -qs "^nogroup:" /etc/group; then
        NOGROUP=nogroup
    else
        NOGROUP=nobody
    fi

    # An old version of easy-rsa was available by default in some openvpn packages
    if [[ -d /etc/openvpn/easy-rsa/ ]]; then
        rm -rf /etc/openvpn/easy-rsa/
    fi

    # Install the latest version of easy-rsa from source
    local version="3.0.5"
    wget -O ~/EasyRSA-nix-${version}.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${version}/EasyRSA-nix-${version}.tgz
    tar xzf ~/EasyRSA-nix-${version}.tgz -C ~/
    mv ~/EasyRSA-${version}/ /etc/openvpn/
    mv /etc/openvpn/EasyRSA-${version}/ /etc/openvpn/easy-rsa/
    chown -R root:root /etc/openvpn/easy-rsa/
    rm -f ~/EasyRSA-nix-${version}.tgz

    cd /etc/openvpn/easy-rsa/
    case $CERT_TYPE in
        1)
            echo "set_var EASYRSA_ALGO ec" > vars
            echo "set_var EASYRSA_CURVE $CERT_CURVE" >> vars
            ;;
        2)
            echo "set_var EASYRSA_KEY_SIZE $RSA_KEY_SIZE" > vars
            ;;
    esac

    # Generate a random, alphanumeric identifier of 16 characters for CN and one for server name
    SERVER_CN="cn_$(
        head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16
        echo ""
    )"
    #	SERVER_CN="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
    SERVER_NAME="server_$(
        head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16
        echo ""
    )"
    #	SERVER_NAME="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
    echo "set_var EASYRSA_REQ_CN $SERVER_CN" >> vars
    # Create the PKI, set up the CA, the DH params and the server certificate
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass

    if [[ $DH_TYPE == "2" ]]; then
        # ECDH keys are generated on-the-fly so we don't need to generate them beforehand
        openssl dhparam -out dh.pem $DH_KEY_SIZE
    fi

    ./easyrsa build-server-full "$SERVER_NAME" nopass
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

    # Move all the generated files
    cp pki/ca.crt pki/private/ca.key "pki/issued/$SERVER_NAME.crt" "pki/private/$SERVER_NAME.key" /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn
    if [[ $DH_TYPE == "2" ]]; then
        cp dh.pem /etc/openvpn
    fi

    # Make cert revocation list readable for non-root
    chmod 644 /etc/openvpn/crl.pem

    # Generate server.conf
    echo "port $PORT" > /etc/openvpn/server.conf
    if [[ "$IPV6_SUPPORT" = 'n' ]]; then
        echo "proto $PROTOCOL" >> /etc/openvpn/server.conf
    elif [[ "$IPV6_SUPPORT" = 'y' ]]; then
        echo "proto ${PROTOCOL}6" >> /etc/openvpn/server.conf
    fi

    echo "dev tun
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" >> /etc/openvpn/server.conf

    # DNS resolvers
    case $DNS in
        1)
            # Locate the proper resolv.conf
            # Needed for systems running systemd-resolved
            if grep -q "127.0.0.53" "/etc/resolv.conf"; then
                RESOLVCONF='/run/systemd/resolve/resolv.conf'
            else
                RESOLVCONF='/etc/resolv.conf'
            fi
            # Obtain the resolvers from resolv.conf and use them for OpenVPN
            grep -v '#' $RESOLVCONF | grep 'nameserver' | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | while read -r line; do
                echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server.conf
            done
            ;;
        2)
            echo 'push "dhcp-option DNS 10.8.0.1"' >> /etc/openvpn/server.conf
            ;;
        3) # Cloudflare
            echo 'push "dhcp-option DNS 1.0.0.1"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server.conf
            ;;
        4) # Quad9
            echo 'push "dhcp-option DNS 9.9.9.9"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 149.112.112.112"' >> /etc/openvpn/server.conf
            ;;
        5) # Quad9 uncensored
            echo 'push "dhcp-option DNS 9.9.9.10"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 149.112.112.10"' >> /etc/openvpn/server.conf
            ;;
        6) # FDN
            echo 'push "dhcp-option DNS 80.67.169.40"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 80.67.169.12"' >> /etc/openvpn/server.conf
            ;;
        7) # DNS.WATCH
            echo 'push "dhcp-option DNS 84.200.69.80"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 84.200.70.40"' >> /etc/openvpn/server.conf
            ;;
        8) # OpenDNS
            echo 'push "dhcp-option DNS 208.67.222.222"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 208.67.220.220"' >> /etc/openvpn/server.conf
            ;;
        9) # Google
            echo 'push "dhcp-option DNS 8.8.8.8"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 8.8.4.4"' >> /etc/openvpn/server.conf
            ;;
        10) # Yandex Basic
            echo 'push "dhcp-option DNS 77.88.8.8"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 77.88.8.1"' >> /etc/openvpn/server.conf
            ;;
        11) # AdGuard DNS
            echo 'push "dhcp-option DNS 176.103.130.130"' >> /etc/openvpn/server.conf
            echo 'push "dhcp-option DNS 176.103.130.131"' >> /etc/openvpn/server.conf
            ;;
    esac
    echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server.conf

    # IPv6 network settings if needed
    if [[ "$IPV6_SUPPORT" = 'y' ]]; then
        echo 'server-ipv6 fd42:42:42:42::/112
tun-ipv6
push tun-ipv6
push "route-ipv6 2000::/3"
push "redirect-gateway ipv6"' >> /etc/openvpn/server.conf
    fi

    if [[ $COMPRESSION_ENABLED == "y" ]]; then
        echo "compress $COMPRESSION_ALG" >> /etc/openvpn/server.conf
    fi

    if [[ $DH_TYPE == "1" ]]; then
        echo "dh none" >> /etc/openvpn/server.conf
        echo "ecdh-curve $DH_CURVE" >> /etc/openvpn/server.conf
    elif [[ $DH_TYPE == "2" ]]; then
        echo "dh dh.pem" >> /etc/openvpn/server.conf
    fi

    case $TLS_SIG in
        1)
            echo "tls-crypt tls-crypt.key 0" >> /etc/openvpn/server.conf
            ;;
        2)
            echo "tls-auth tls-auth.key 0" >> /etc/openvpn/server.conf
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
status /var/log/openvpn/status.log
verb 3" >> /etc/openvpn/server.conf

    # Create log dir
    mkdir -p /var/log/openvpn

    # Enable routing
    echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/20-openvpn.conf
    if [[ "$IPV6_SUPPORT" = 'y' ]]; then
        echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.d/20-openvpn.conf
    fi
    # Avoid an unneeded reboot
    sysctl --system

    # If SELinux is enabled and a custom port was selected, we need this
    if hash sestatus 2> /dev/null; then
        if sestatus | grep "Current mode" | grep -qs "enforcing"; then
            if [[ "$PORT" != '1194' ]]; then
                semanage port -a -t openvpn_port_t -p "$PROTOCOL" "$PORT"
            fi
        fi
    fi

    # Finally, restart and enable OpenVPN
    if [[ "$OS" = 'arch' || "$OS" = 'fedora' ]]; then
        # Don't modify package-provided service
        cp /usr/lib/systemd/system/openvpn-server@.service /etc/systemd/system/openvpn-server@.service

        # Workaround to fix OpenVPN service on OpenVZ
        sed -i 's|LimitNPROC|#LimitNPROC|' /etc/systemd/system/openvpn-server@.service
        # Another workaround to keep using /etc/openvpn/
        sed -i 's|/etc/openvpn/server|/etc/openvpn|' /etc/systemd/system/openvpn-server@.service
        # On fedora, the service hardcodes the ciphers. We want to manage the cipher ourselves, so we remove it from the service
        if [[ "$OS" == "fedora" ]]; then
            sed -i 's|--cipher AES-256-GCM --ncp-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC:AES-128-CBC:BF-CBC||' /etc/systemd/system/openvpn-server@.service
        fi

        systemctl daemon-reload
        systemctl restart openvpn-server@server
        systemctl enable openvpn-server@server
    elif [[ "$OS" == "ubuntu" ]] && [[ "$VERSION_ID" == "16.04" ]]; then
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
        systemctl restart openvpn@server
        systemctl enable openvpn@server
    fi

    if [[ $DNS == 2 ]]; then
        installUnbound
    fi

    # Add iptables rules in two scripts
    mkdir /etc/iptables

    # Script to add rules
    echo "#!/bin/sh
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -A INPUT -i tun0 -j ACCEPT
iptables -A FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -A INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" > /etc/iptables/add-openvpn-rules.sh

    if [[ "$IPV6_SUPPORT" = 'y' ]]; then
        echo "ip6tables -t nat -A POSTROUTING -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -A INPUT -i tun0 -j ACCEPT
ip6tables -A FORWARD -i $NIC -o tun0 -j ACCEPT
ip6tables -A FORWARD -i tun0 -o $NIC -j ACCEPT" >> /etc/iptables/add-openvpn-rules.sh
    fi

    # Script to remove rules
    echo "#!/bin/sh
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $NIC -j MASQUERADE
iptables -D INPUT -i tun0 -j ACCEPT
iptables -D FORWARD -i $NIC -o tun0 -j ACCEPT
iptables -D FORWARD -i tun0 -o $NIC -j ACCEPT
iptables -D INPUT -i $NIC -p $PROTOCOL --dport $PORT -j ACCEPT" > /etc/iptables/rm-openvpn-rules.sh

    if [[ "$IPV6_SUPPORT" = 'y' ]]; then
        echo "ip6tables -t nat -D POSTROUTING -s fd42:42:42:42::/112 -o $NIC -j MASQUERADE
ip6tables -D INPUT -i tun0 -j ACCEPT
ip6tables -D FORWARD -i $NIC -o tun0 -j ACCEPT
ip6tables -D FORWARD -i tun0 -o $NIC -j ACCEPT" >> /etc/iptables/rm-openvpn-rules.sh
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
WantedBy=multi-user.target" > /etc/systemd/system/iptables-openvpn.service

    # Enable service and apply rules
    systemctl daemon-reload
    systemctl enable iptables-openvpn
    systemctl start iptables-openvpn

    # If the server is behind a NAT, use the correct IP address for the clients to connect to
    if [[ "$PUBLICIP" != "" ]]; then
        IP=$PUBLICIP
    fi

    # client-template.txt is created so we have a template to add further users later
    echo "client" > /etc/openvpn/client-template.txt
    if [[ "$PROTOCOL" = 'udp' ]]; then
        echo "proto udp" >> /etc/openvpn/client-template.txt
    elif [[ "$PROTOCOL" = 'tcp' ]]; then
        echo "proto tcp-client" >> /etc/openvpn/client-template.txt
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
setenv opt block-outside-dns # Prevent Windows 10 DNS leak
verb 3" >> /etc/openvpn/client-template.txt

    if [[ $COMPRESSION_ENABLED == "y" ]]; then
        echo "compress $COMPRESSION_ALG" >> /etc/openvpn/client-template.txt
    fi

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
    echo "If you want to add more clients, you simply need to run this script another time!"
}

function newClient() {

    PASS="1"

    cd /etc/openvpn/easy-rsa/ || return
    case $PASS in
        1)
            ./easyrsa build-client-full "$CLIENT" nopass
            ;;
        2)
            echo "⚠️ You will be asked for the client password below ⚠️"
            ./easyrsa build-client-full "$CLIENT"
            ;;
    esac

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
        awk '/BEGIN/,/END/' "/etc/openvpn/easy-rsa/pki/issued/$CLIENT.crt"
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
    } >> "$homeDir/$CLIENT.ovpn"

    echo ""
    echo "Client $CLIENT added, the configuration file is available at $homeDir/$CLIENT.ovpn."
    echo "Download the .ovpn file and import it in your OpenVPN client."
}

function revokeClient() {
    NUMBEROFCLIENTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
    if [[ "$NUMBEROFCLIENTS" = '0' ]]; then
        echo ""
        echo "You have no existing clients!"
        exit 1
    fi

    echo ""
    echo "Select the existing client certificate you want to revoke"
    tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
    if [[ "$NUMBEROFCLIENTS" = '1' ]]; then
        read -rp "Select one client [1]: " CLIENTNUMBER
    else
        read -rp "Select one client [1-$NUMBEROFCLIENTS]: " CLIENTNUMBER
    fi

    CLIENT=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
    cd /etc/openvpn/easy-rsa/
    ./easyrsa --batch revoke "$CLIENT"
    EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
    # Cleanup
    rm -f "pki/reqs/$CLIENT.req"
    rm -f "pki/private/$CLIENT.key"
    rm -f "pki/issued/$CLIENT.crt"
    rm -f /etc/openvpn/crl.pem
    cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
    chmod 644 /etc/openvpn/crl.pem
    find /home/ -maxdepth 2 -name "$CLIENT.ovpn" -delete
    rm -f "/root/$CLIENT.ovpn"
    sed -i "s|^$CLIENT,.*||" /etc/openvpn/ipp.txt

    echo ""
    echo "Certificate for client $CLIENT revoked."
}

function removeUnbound() {
    # Remove OpenVPN-related config
    sed -i 's|include: \/etc\/unbound\/openvpn.conf||' /etc/unbound/unbound.conf
    rm /etc/unbound/openvpn.conf
    systemctl restart unbound

    until [[ $REMOVE_UNBOUND =~ (y|n) ]]; do
        echo ""
        echo "If you were already using Unbound before installing OpenVPN, I removed the configuration related to OpenVPN."
        read -rp "Do you want to completely remove Unbound? [y/n]: " -e REMOVE_UNBOUND
    done

    if [[ "$REMOVE_UNBOUND" = 'y' ]]; then
        # Stop Unbound
        systemctl stop unbound

        if [[ "$OS" =~ (debian|ubuntu) ]]; then
            apt_remove --purge unbound
        elif [[ "$OS" = 'arch' ]]; then
            pacman --noconfirm -R unbound
        elif [[ "$OS" = 'centos' ]]; then
            yum remove -y unbound
        elif [[ "$OS" = 'fedora' ]]; then
            dnf remove -y unbound
        fi

        rm -rf /etc/unbound/

        echo ""
        echo "Unbound removed!"
    else
        echo ""
        echo "Unbound wasn't removed."
    fi
}

function removeOpenVPN() {
    echo ""
    read -rp "Do you really want to remove OpenVPN? [y/n]: " -e -i n REMOVE
    if [[ "$REMOVE" = 'y' ]]; then
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
            apt_remove --purge openvpn
            if [[ -e /etc/apt/sources.list.d/openvpn.list ]]; then
                rm /etc/apt/sources.list.d/openvpn.list
                apt_update
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
    else
        echo ""
        echo "Removal aborted!"
    fi
}

function manageMenu() {
    clear
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
    until [[ "$MENU_OPTION" =~ ^[1-4]$ ]]; do
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
if [[ -e /etc/openvpn/server.conf ]]; then
    manageMenu #do add user instead with default value
else
    installOpenVPN
fi

touch /install/.openvpn2.lock
