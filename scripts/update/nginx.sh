#!/bin/bash

function update_nginx() {
    codename=$(lsb_release -cs)

    # This is the operation that breaks nginx: removing libnginx-mod-http-geoip makes apt
    # pull in the Sury nginx and leaves nginx half-removed. It MUST run before the self-heal
    # below so the same `box update` repairs the breakage it causes - otherwise the box
    # finishes this run with nginx broken and only heals on the *next* update (which is why
    # it used to need a second, manual `box update` over SSH to come back).
    # It's preinstalled on the template, unused, and after it's gone this is a harmless no-op.
    apt_remove libnginx-mod-http-geoip

    # Sury nginx packages get pulled in by unrelated apt operations (the geoip removal above,
    # and apt_upgrade earlier in `box update`) and leave nginx half-removed/broken. Detect and
    # repair before doing anything else so the rest of this update has a working nginx
    # to configure. See scripts/install/nginx.sh php-opcache removal for the root cause.
    if dpkg -l 2> /dev/null | grep "nginx" | grep -q "sury"; then
        echo_warn "Sury nginx packages detected - purging and reinstalling nginx"
        apt_remove --purge 'nginx*' 'libnginx-mod-*'
        apt-get update --fix-missing >> "${log}" 2>&1 || apt-get update >> "${log}" 2>&1
        rm -f /install/.nginx.lock
        box install nginx
    elif ! command -v nginx > /dev/null 2>&1; then
        echo_warn "nginx binary missing - reinstalling nginx"
        rm -f /install/.nginx.lock
        box install nginx
    fi

    # box install nginx's per-app config loop matches script filenames to lock files
    # (scripts/nginx/qbittorrent.sh <-> .qbittorrent.lock), so it never re-applies for
    # qBittorrent5, which reuses that same script but ships under .qbittorrent5.lock.
    # Reapply it directly instead of doing a full qbittorrent5 reinstall.
    if [[ -f /install/.qbittorrent5.lock ]] && [[ -f /install/.nginx.lock ]]; then
        bash /etc/swizzin/scripts/nginx/qbittorrent.sh
        systemctl reload nginx
    fi

    if [[ $codename =~ ("xenial"|"stretch") ]]; then
        mcrypt=php-mcrypt
    else
        mcrypt=
    fi

    #Deprecate nginx-extras in favour of installing fancyindex alone
    # (unless you use xenial)
    if [[ ! $codename == "xenial" ]]; then
        if dpkg -s nginx-extras > /dev/null 2>&1; then
            apt_remove nginx-extras
            apt_install nginx libnginx-mod-http-fancyindex
            apt_autoremove
            rm $(ls -d /etc/nginx/modules-enabled/*.removed)
            systemctl reload nginx
        fi
    fi

    LIST="php8.0-fpm php8.0-cli php8.0-dev php8.0-xml php8.0-curl php8.0-mcrypt php8.0-mbstring php8.0-xml"
    #php-geoip php-json

    missing=()
    for dep in $LIST; do
        if ! check_installed "$dep"; then
            missing+=("$dep")
        fi
    done

    if [[ ${missing[1]} != "" ]]; then
        # echo_inf "Installing the following dependencies: ${missing[*]}" | tee -a $log
        apt_install "${missing[@]}"
    fi

    cd /etc/php
    phpv=$(ls -d */ | cut -d/ -f1)
    if [[ $phpv =~ 7\\.1 ]]; then
        if [[ $phpv =~ 7\\.0 ]]; then
            apt_remove --purge php7.0-fpm
        fi
    fi

    # Purge all PHP versions except 8.0 and 7.3
    for phpdir in /etc/php/*; do
        if [[ -d "$phpdir" ]]; then
            phpver=$(basename "$phpdir")
            if [[ "$phpver" != "8.0" && "$phpver" != "7.3" ]]; then
                echo "Purging PHP version $phpver"
                apt_remove --purge php${phpver}*
            fi
        fi
    done

    . /etc/swizzin/sources/functions/php
    phpversion=$(php_service_version)
    sock="php${phpversion}-fpm"

    if [[ $phpversion != "8.0" ]]; then
        echo "wrong php version: $phpversion cleaning up"
        sudo update-alternatives --set php /usr/bin/php8.0
    fi

    #    _apt_reset
    #    #also purge this guy
    #    if check_installed "php8.0-xmlrpc"; then
    #      apt purge -y "php8.0-xmlrpc" > /dev/null 2>&1;
    #    fi
    #
    #    PURGE="5.6 7.0 7.1 7.2 7.4";
    #    for ver in $PURGE; do
    #        apt purge -y "php$ver*" > /dev/null 2>&1;
    #        rm -rf "/etc/php/$ver";
    #    done;
    #
    #    if [[ ! -f /install/.nextcloud.lock ]]; then
    #        apt_remove --purge "php7.3*" > /dev/null 2>&1;
    #        rm -rf "/etc/php/7.3";
    #    fi

    for version in $phpv; do
        if [[ -f /etc/php/$version/fpm/php.ini ]]; then
            sed -i -e "s/post_max_size = 8M/post_max_size = 64M/" \
                -e "s/upload_max_filesize = 2M/upload_max_filesize = 92M/" \
                -e "s/expose_php = On/expose_php = Off/" \
                -e "s/128M/768M/" \
                -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" \
                -e "s/;opcache.enable=0/opcache.enable=1/" \
                -e "s/;opcache.memory_consumption=64/opcache.memory_consumption=128/" \
                -e "s/;opcache.max_accelerated_files=2000/opcache.max_accelerated_files=4000/" \
                -e "s/;opcache.revalidate_freq=2/opcache.revalidate_freq=240/" /etc/php/$version/fpm/php.ini
            phpenmod -v $version opcache
        fi
    done

    if [[ ! -f /etc/nginx/modules-enabled/50-mod-http-fancyindex.conf ]]; then
        mkdir -p /etc/nginx/modules-enabled/
        ln -s /usr/share/nginx/modules-available/mod-http-fancyindex.conf /etc/nginx/modules-enabled/50-mod-http-fancyindex.conf
    fi

    phpversion=$(php_service_version)

    fcgis=($(find /etc/nginx -type f -exec grep -l "fastcgi_pass unix:/run/php/" {} \;))
    err=()
    for f in ${fcgis[@]}; do
        err+=($(grep -L "fastcgi_pass unix:/run/php/php${phpversion}-fpm.sock" $f))
    done
    for fix in ${err[@]}; do
        sed -i "s/fastcgi_pass .*/fastcgi_pass unix:\/run\/php\/php${phpversion}-fpm.sock;/g" $fix
    done

    if grep -q -e "-dark" -e "Nginx-Fancyindex" /srv/fancyindex/header.html; then
        sed -i 's/href="\/[^\/]*/href="\/fancyindex/g' /srv/fancyindex/header.html
    fi

    if grep -q "Nginx-Fancyindex" /srv/fancyindex/footer.html; then
        sed -i 's/src="\/[^\/]*/src="\/fancyindex/g' /srv/fancyindex/footer.html
    fi

    if [[ -f /install/.rutorrent.lock ]]; then
        cat > /etc/nginx/apps/rindex.conf << EOR
location /rtorrent.downloads {
  alias /home/\$remote_user/torrents/rtorrent;
  include /etc/nginx/snippets/fancyindex.conf;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;

  location ~* \.php\$ {

  }
}
location /rtorrent.downloads.plain {
  alias /home/\$remote_user/torrents/rtorrent;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;
  autoindex on;
  location ~* \.php\$ {

  }
}
EOR
    fi

    if [[ -f /install/.deluge.lock ]]; then
        cat > /etc/nginx/apps/dindex.conf << DIN
location /deluge.downloads {
  alias /home/\$remote_user/torrents/deluge;
  include /etc/nginx/snippets/fancyindex.conf;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;

  location ~* \.php\$ {

  }
}
location /deluge.downloads.plain {
  alias /home/\$remote_user/torrents/deluge;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;
  autoindex on;
  location ~* \.php\$ {

  }
}
DIN
    fi

    if [[ -f /install/.transmission.lock ]]; then
        cat > /etc/nginx/apps/tindex.conf << DIN
location /transmission.downloads {
  alias /home/\$remote_user/torrents/transmission;
  include /etc/nginx/snippets/fancyindex.conf;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;

  location ~* \.php\$ {

  }
}
location /transmission.downloads.plain {
  alias /home/\$remote_user/torrents/transmission;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;
  autoindex on;
  location ~* \.php\$ {

  }
}
DIN
    fi

    if [[ -f /install/.qbittorrent.lock ]]; then
        cat > /etc/nginx/apps/qbtindex.conf << DIN
location /qbittorrent.downloads {
  alias /home/\$remote_user/torrents/qbittorrent;
  include /etc/nginx/snippets/fancyindex.conf;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;

  location ~* \.php\$ {

  }
}
location /qbittorrent.downloads.plain {
  alias /home/\$remote_user/torrents/qbittorrent;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd;
  autoindex on;
  location ~* \.php\$ {

  }
}
DIN
    fi

    # Remove php directive at the root level since we no longer use php
    # on root and we define php manually for nested locations
    if grep -q '\.php\$' /etc/nginx/sites-enabled/default; then
        sed -i -e '/location ~ \\.php$ {/,/}/d' /etc/nginx/sites-enabled/default
    fi

    # Remove fancy index location block because it's now an app conf
    if grep -q 'fancyindex' /etc/nginx/sites-enabled/default; then
        sed -i -e '/location \/fancyindex {/,/}/d' /etc/nginx/sites-enabled/default
    fi

    # Create fancyindex conf if not exists
    if [[ ! -f /etc/nginx/apps/fancyindex.conf ]] || grep -q posterity /etc/nginx/apps/fancyindex.conf > /dev/null 2>&1; then
        cat > /etc/nginx/apps/fancyindex.conf << FIAC
location /fancyindex {
    location ~ \.php($|/) {
        fastcgi_split_path_info ^(.+?\.php)(/.+)$;
        # Work around annoying nginx "feature" (https://trac.nginx.org/nginx/ticket/321)
        set \$path_info \$fastcgi_path_info;
        fastcgi_param PATH_INFO \$path_info;

        try_files \$fastcgi_script_name =404;
        fastcgi_pass unix:/run/php/${sock}.sock;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
        include fastcgi_params;
        fastcgi_index index.php;
    }
}
FIAC
    fi

    if grep -q 'index.html' /etc/nginx/sites-enabled/default; then
        sed -i '/index.html/d' /etc/nginx/sites-enabled/default
    fi

    # Upgrade SSL Protocols
    # if grep -q 'ssl_protocols TLSv1 TLSv1.1 TLSv1.2;' /etc/nginx/snippets/ssl-params.conf; then
    #     # Upgrades protocols to 1.2/1.3
    #     sed 's|ssl_protocols TLSv1 TLSv1.1 TLSv1.2;|ssl_protocols TLSv1.2 TLSv1.3;|g' -i /etc/nginx/snippets/ssl-params.conf
    #     # Changes cyphers
    #     sed 's|ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";|ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:EECDH+AESGCM:EDH+AESGCM;|g' -i /etc/nginx/snippets/ssl-params.conf
    # fi

    if grep -q 'ssl_protocols TLSv1.2 TLSv1.3;' /etc/nginx/snippets/ssl-params.conf; then
        # Upgrades protocols to 1.2/1.3
        sed 's|ssl_protocols TLSv1.2 TLSv1.3;|ssl_protocols TLSv1 TLSv1.1 TLSv1.2;|g' -i /etc/nginx/snippets/ssl-params.conf
        # Changes cyphers
        sed 's|ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:EECDH+AESGCM:EDH+AESGCM;|ssl_ciphers "EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH";|g' -i /etc/nginx/snippets/ssl-params.conf
    fi

    # Upgrade to http/2
    if grep -q 'listen 443 ssl default_server;' /etc/nginx/sites-enabled/default; then
        # IPV4 http2 upgrade
        sed 's|listen 443 ssl default_server;|listen 443 ssl http2 default_server;|g' -i /etc/nginx/sites-enabled/default
        # IPV6 http2 upgrade
        sed 's|listen \[::]\:443 ssl default_server;|listen \[::]\:443 ssl http2 default_server;|g' -i /etc/nginx/sites-enabled/default
    fi

    # fix /etc/nginx/sites-enabled/default to not cause nginx to fail on reloading when there are subdirectories in /etc/nginx/apps like /etc/nginx/apps/authelia
    sed 's|include /etc/nginx/apps/\*;|include /etc/nginx/apps/\*.conf;|g' -i /etc/nginx/sites-enabled/default

    # we will do this in tools update
    #    . /etc/swizzin/sources/functions/php
    #    restart_php_fpm
    systemctl reload nginx
}

# Ensure nginx is actually installed before the lock-gated updater below. box update
# previously skipped everything here whenever /install/.nginx.lock was absent, so a box
# whose nginx install failed or was purged (lock removed) never self-healed on update.
# If the binary is missing, (re)install it; scripts/install/nginx.sh recreates the lock
# on success, which then lets update_nginx run.
if ! command -v nginx > /dev/null 2>&1; then
    echo_warn "nginx not installed - installing via box update"
    rm -f /install/.nginx.lock
    box install nginx
fi

if [[ -f /install/.nginx.lock ]]; then update_nginx; fi
