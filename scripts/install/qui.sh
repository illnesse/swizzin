#!/bin/bash
# qui installation script for Swizzin
# Install location: /etc/swizzin/scripts/install/qui.sh
# Author: Seedit4.me
# Installation script for qui - Modern qBittorrent Web UI

user=$(cut -d: -f1 < /root/.master.info)
password=$(cut -d: -f2 < /root/.master.info)

echo_progress_start "Downloading qui"
cd /tmp
wget -q $(curl -s https://api.github.com/repos/autobrr/qui/releases/latest | grep browser_download_url | grep linux_x86_64 | cut -d\" -f4)
tar -C /usr/local/bin -xzf qui*.tar.gz
rm qui*.tar.gz
echo_progress_done "qui downloaded"

echo_progress_start "Configuring qui"
mkdir -p /home/${user}/.config/qui/data
mkdir -p /var/log/qui
chown -R ${user}:${user} /home/${user}/.config/qui
chown -R ${user}:${user} /var/log/qui

# Generate config
sudo -u ${user} qui generate-config --config-dir /home/${user}/.config/qui/

# Set base URL in config
sed -i 's|^#*\s*baseUrl\s*=.*|baseUrl = "/qui/"|' /home/${user}/.config/qui/config.toml
sed -i 's|^#*\s*host\s*=.*|host = "127.0.0.1"|' /home/${user}/.config/qui/config.toml
sed -i 's|^#*\s*logPath\s*=.*|logPath = "/var/log/qui/qui.log"|' /home/${user}/.config/qui/config.toml

echo_progress_done "qui configured"

echo_progress_start "Creating qui systemd service"
cat > /etc/systemd/system/qui.service <<EOF
[Unit]
Description=qui - Modern qBittorrent Web UI
After=network.target qbittorrent.service
Wants=qbittorrent.service

[Service]
Type=simple
User=${user}
Group=${user}
WorkingDirectory=/home/${user}
ExecStart=/usr/local/bin/qui serve --config-dir /home/${user}/.config/qui/
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/${user}/.config/qui /var/log/qui
LimitNOFILE=8192

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable -q --now qui
echo_progress_done "qui service created"

echo_progress_start "Configuring nginx"
cat > /etc/nginx/apps/qui.conf <<'QUINGINX'
location /qui/ {
    proxy_pass http://127.0.0.1:7476/qui/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600;
    proxy_send_timeout 3600;
}
QUINGINX

systemctl reload nginx
echo_progress_done "nginx configured"

echo_progress_start "Creating qui user account"
# Always use 'seedit4me' as username with client dash password (consistent with other apps)
sudo -u ${user} qui create-user \
  --config-dir /home/${user}/.config/qui/ \
  --username seedit4me \
  --password "${password}"
echo_progress_done "qui user created"

touch /install/.qui.lock
echo_success "qui installed successfully"
echo_info "Access qui at: https://[container].ftl[XX].seedit4.me/qui/"
echo_info "Username: seedit4me"
echo_info "Password: [client dash password]"
