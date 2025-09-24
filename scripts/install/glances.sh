# Grab swizzin masteruser
user=$(cut -d: -f1 < /root/.master.info)

echo_progress_done "installing dependencies"

apt_install glances

echo_progress_start "Installing reverse proxy config..."

cat > /etc/nginx/apps/glances.conf << GLN
port_in_redirect off;

location /glances/ {
  rewrite /glances/(.*) /\$1 break;
  proxy_pass http://localhost:61208/;
  proxy_set_header Host \$http_host;
  proxy_set_header X-Real-IP \$remote_addr;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;

  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd.d/htpasswd.${user};
}
GLN

service nginx restart

echo_progress_start "Installing systemd service..."

cat << FOE >> /etc/systemd/system/glancesweb.service
[Unit]
Description=Glances Webserver
After=network.target

[Service]
ExecStart=/usr/bin/glances -w -t 5
Restart=on-abort
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
FOE

systemctl daemon-reload
systemctl enable --now glancesweb

sudo touch /install/.glances.lock

echo_progress_done "Done installing Glances"
