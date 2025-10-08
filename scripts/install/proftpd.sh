#!/bin/bash
# proftpd installer
# Author: Nobody
# Copyright (C) 2017 Nobody
# Licensed under DWYW (Do Whatever you want).
#
#   You may copy, distribute and modify the software.

echo_progress_start "getting ports/ip"
if [[ -f /home/seedit4me/.pasv_port ]]; then
  pasvports=$(cat /home/seedit4me/.pasv_port)
  pasv=(${pasvports//:/ })
  pubip=$(curl -s http://ipv4.icanhazip.com)
else
  echo_warn "missing port file., bailing out";
  exit 1;
fi
echo_progress_done "k"

echo_progress_start "installing packages"
apt_install debconf-utils >> "${log}" 2>&1
echo "proftpd-basic shared/proftpd/inetd_or_standalone select standalone" | debconf-set-selections >> "${log}" 2>&1
apt_install proftpd-basic proftpd-mod-crypto >> "${log}" 2>&1
mkdir -p /etc/proftpd/
echo_progress_done "done"

echo_progress_start "configuring"
cat > /etc/proftpd/proftpd.conf << PFC

Include /etc/proftpd/modules.conf

### ECM CUSTOM ###
PassivePorts            ${pasv[0]} ${pasv[1]}
MasqueradeAddress		$pubip
AllowForeignAddress		on
RequireValidShell		off
Port				21
### ECM CUSTOM ###

UseIPv6				on
# IdentLookups			off
ServerName			"Debian"
ServerType			standalone
DeferWelcome			off
# MultilineRFC2228		on
DefaultServer			on
ShowSymlinks			on
TimeoutNoTransfer		600
TimeoutStalled			600
TimeoutIdle			1200
# TLSRenegotiate none
# TLSOptions NoSessionReuseRequired
DisplayLogin                    welcome.msg
DisplayChdir               	.message true
ListOptions                	"-l"
DenyFilter			\*.*/
<IfModule mod_dynmasq.c>
# DynMasqRefresh 28800
</IfModule>
MaxInstances			30
User				proftpd
Group				nogroup
Umask				022  022
AllowOverwrite			on
AllowStoreRestart on
AllowRetrieveRestart on
AuthOrder			mod_auth_pam.c* mod_auth_unix.c
TransferLog /var/log/proftpd/xferlog
SystemLog   /var/log/proftpd/proftpd.log
<IfModule mod_quotatab.c>
QuotaEngine off
</IfModule>
<IfModule mod_ratio.c>
Ratios off
</IfModule>
<IfModule mod_delay.c>
DelayEngine on
</IfModule>

<IfModule mod_ctrls.c>
ControlsEngine        off
ControlsMaxClients    2
ControlsLog           /var/log/proftpd/controls.log
ControlsInterval      5
ControlsSocket        /var/run/proftpd/proftpd.sock
</IfModule>
<IfModule mod_ctrls_admin.c>
AdminControlsEngine off
</IfModule>
Include /etc/proftpd/conf.d/

PFC

echo 'DefaultRoot ~' >> /etc/proftpd/proftpd.conf
echo 'ServerIdent on "hosted by https://seedit.me"' >> /etc/proftpd/proftpd.conf
echo_progress_done "done"

echo_progress_start "Setting up SSL"
apt_install openssl
mkdir /etc/proftpd/ssl

#Required
domain='ftp.seedit4.me'
commonname=$domain

#Change to your company details
country=GB
state=Nottingham
locality=Nottinghamshire
organization='seedit4.me'
organizationalunit=IT
email=support@seedit4.me
openssl req -new -x509 -days 365 -nodes -out /etc/proftpd/ssl/proftpd.cert.pem -keyout /etc/proftpd/ssl/proftpd.key.pem -subj "/C=$country/ST=$state/L=$locality/O=$organization/OU=$organizationalunit/CN=$commonname/emailAddress=$email"
chmod 600 /etc/proftpd/ssl/proftpd.*

echo 'Include /etc/proftpd/tls.conf' >> /etc/proftpd/proftpd.conf
cat > /etc/proftpd/tls.conf << TLS
<IfModule mod_tls.c>
TLSEngine on
TLSLog /var/log/proftpd/tls.log
TLSProtocol TLSv1.2 TLSv1.3
TLSCipherSuite AES128+EECDH:AES128+EDH
TLSOptions AllowClientRenegotiations
TLSRSACertificateFile /etc/proftpd/ssl/proftpd.cert.pem
TLSRSACertificateKeyFile /etc/proftpd/ssl/proftpd.key.pem
TLSVerifyClient off
TLSRequired off
RequireValidShell no
</IfModule>
TLS

sudo chown root:root /etc/proftpd/tls.conf
sudo chmod 644 /etc/proftpd/tls.conf
sudo chmod 755 /etc/proftpd /etc/proftpd/ssl

echo "LoadModule mod_tls.c" >> /etc/proftpd/modules.conf


echo_progress_done "done"

echo_progress_start "Setting up SSL"
systemctl restart proftpd.service
echo_progress_done "done"

echo_success "ProFTPd installed"

touch /install/.proftpd.lock
