#!/usr/bin/env bash
# Seerr nginx proxy configuration for swizzin
# Proxies /seerr to the local Seerr instance on port 5055

cat > /etc/nginx/apps/seerr.conf << 'EOF'
location ^~ /seerr {
    set $app 'seerr';

    # Remove /seerr path to pass to the app
    rewrite ^/seerr/?(.*)$ /$1 break;
    proxy_pass http://127.0.0.1:5055; # NO TRAILING SLASH

    # Redirect location headers
    proxy_redirect ^ /$app;
    proxy_redirect /setup /$app/setup;
    proxy_redirect /login /$app/login;

    # Sub filters to replace hardcoded paths
    proxy_set_header Accept-Encoding "";
    sub_filter_once off;
    sub_filter_types *;
    sub_filter 'href="/"' 'href="/$app"';
    sub_filter 'href="/login"' 'href="/$app/login"';
    sub_filter 'href:"/"' 'href:"/$app"';
    sub_filter '\/_next' '\/$app\/_next';
    sub_filter '/_next' '/$app/_next';
    sub_filter '/api/v1' '/$app/api/v1';
    sub_filter '/login/plex/loading' '/$app/login/plex/loading';
    sub_filter '/images/' '/$app/images/';
    sub_filter '/imageproxy/' '/$app/imageproxy/';
    sub_filter '/avatarproxy/' '/$app/avatarproxy/';
    sub_filter '/android-' '/$app/android-';
    sub_filter '/apple-' '/$app/apple-';
    sub_filter '/favicon' '/$app/favicon';
    sub_filter '/logo_' '/$app/logo_';
    sub_filter '/site.webmanifest' '/$app/site.webmanifest';
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
