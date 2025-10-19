#!/bin/bash
# vsftpd installer
# Author: liara
# Copyright (C) 2017 Swizzin
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#


echo_progress_start "getting ports/ip"
if [[ -f /home/seedit4me/.pasv_port ]]; then
  pasvports=$(cat /home/seedit4me/.pasv_port)
  pasv=(${pasvports//:/ })
else
  echo_warn "missing port file., bailing out";
  exit 1;
fi
echo_progress_done "k"

echo_progress_start "installing packages"
apt_install vsftpd ssl-cert
echo_progress_done "done"

echo_progress_start "Configuring vsftpd"
cat > /etc/vsftpd.conf << VSC
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
force_dot_files=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
utf8_filesystem=YES
require_ssl_reuse=NO
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=YES
pam_service_name=vsftpd
secure_chroot_dir=/var/run/vsftpd/empty

ascii_upload_enable=YES
ascii_download_enable=YES
ftpd_banner=Welcome to blah FTP service.

listen_port=21
#pasv_addr_resolve=YES
pasv_enable=YES
pasv_promiscuous=YES
port_promiscuous=YES
pasv_min_port=${pasv[0]}
pasv_max_port=${pasv[1]}

force_local_data_ssl=NO
force_local_logins_ssl=NO

debug_ssl=YES
xferlog_enable=YES

ftpd_banner=/etc/swizzin/sources/logo/logo1
banner_file=/etc/swizzin/sources/logo/logo1
VSC

# Check for LE cert, and copy it if available.
# shellcheck source=sources/functions/letsencrypt
. /etc/swizzin/sources/functions/letsencrypt
le_vsftpd_hook

systemctl restart vsftpd
echo_progress_done "Configured vsftpd"

echo_success "Vsftpd installed"
touch /install/.vsftpd.lock
