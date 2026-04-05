#!/usr/bin/env bash
# Seerr nginx proxy configuration for swizzin
# Proxies /seerr to the local Seerr instance on port 5055

cat > /etc/nginx/apps/seerr.conf << 'EOF'
location /seerr/ {
    proxy_pass http://127.0.0.1:5055/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_read_timeout 86400;
}
EOF

# Bind Seerr to localhost only when proxied via nginx
if [[ -f /etc/seerr/seerr.conf ]]; then
    sed -i 's|^#\s*HOST=127\.0\.0\.1|HOST=127.0.0.1|g' /etc/seerr/seerr.conf
    # Ensure HOST line is present
    if ! grep -q "^HOST=" /etc/seerr/seerr.conf; then
        echo "HOST=127.0.0.1" >> /etc/seerr/seerr.conf
    fi
fi

systemctl try-restart seerr
