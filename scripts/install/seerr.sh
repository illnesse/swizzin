#!/usr/bin/env bash
# Seerr installer for swizzin
# https://github.com/seerr-team/seerr
# Build from source: https://docs.seerr.dev/getting-started/buildfromsource

#shellcheck source=sources/functions/seerr
. /etc/swizzin/sources/functions/seerr

function _create_user() {
    echo_progress_start "Creating seerr system user"
    if ! getent group seerr > /dev/null 2>&1; then
        addgroup --system seerr >> "$log" 2>&1
    fi
    if ! getent passwd seerr > /dev/null 2>&1; then
        adduser --system --no-create-home --ingroup seerr seerr >> "$log" 2>&1
    fi
    echo_progress_done "seerr user created"
}

function _install_deps() {
    apt_install git curl
}

function _create_config() {
    echo_progress_start "Creating Seerr environment config"
    mkdir -p /etc/seerr
    cat > /etc/seerr/seerr.conf << 'EOF'
## Seerr environment configuration

## Port to listen on (default: 5055)
PORT=5055

## Interface to listen on (127.0.0.1 = localhost only, required for nginx proxy)
HOST=127.0.0.1

## Uncomment to force Node.js to resolve IPv4 before IPv6 (advanced users only)
# FORCE_IPV4_FIRST=true
EOF
    chown -R seerr:seerr /etc/seerr
    echo_progress_done "Config created"
}

function _create_service() {
    echo_progress_start "Creating Seerr systemd service"
    node_bin="$(command -v node)"
    cat > /etc/systemd/system/seerr.service << EOF
[Unit]
Description=Seerr Service
Wants=network-online.target
After=network-online.target

[Service]
EnvironmentFile=/etc/seerr/seerr.conf
Environment=NODE_ENV=production
Type=exec
User=seerr
Group=seerr
Restart=on-failure
RestartSec=5
WorkingDirectory=/opt/seerr
ExecStart=${node_bin} dist/index.js

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    echo_progress_done "Service created"
}

function _nginx() {
    if [[ -f /install/.nginx.lock ]]; then
        echo_progress_start "Configuring nginx"
        bash /usr/local/bin/swizzin/nginx/seerr.sh
        systemctl reload nginx
        echo_progress_done "Nginx configured"
    else
        echo_info "Seerr is accessible on port 5055"
    fi
}

_install_deps
_create_user
seerr_build
_create_config
_create_service

echo_progress_start "Enabling and starting Seerr"
systemctl enable --now -q seerr >> "$log" 2>&1
echo_progress_done "Seerr started"

_nginx

touch /install/.seerr.lock
echo_success "Seerr installed"
echo_info "Access Seerr at http://localhost:5055 or via the /seerr nginx proxy if nginx is installed"
