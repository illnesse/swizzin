#!/bin/bash
#
# [Install nextcloud package]
#
# Author:   liara for QuickBox.io
# Ported to swizzin by liara
#
# QuickBox Copyright (C) 2017 QuickBox.io
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.

inst=$(which mysql)
user=$(cut -d: -f1 </root/.master.info)
nextpass=$(cut -d: -f2 </root/.master.info)
password=$(cut -d: -f2 </root/.master.info)

inst=$(mysql -V)
ip=$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')
if [[ ! -f /install/.nginx.lock ]]; then
    echo_error "Web server not detected. Please install nginx and restart panel install."
    exit 1
else
    if [[ -n $inst ]]; then
        echo_warn "Existing mysql server detected!"
    else
        echo_progress_start "Installing database"
        apt_install mariadb-server
        if [[ $(systemctl is-active mysql) != "active" ]]; then
            systemctl start mysql
        fi
        mysqladmin -u root password ${password}
        echo_progress_done "Database installed"
    fi
    #Depends
    apt_install unzip php8.0-mysql libxml2-dev php8.0-common php8.0-gd php8.0-curl php8.0-zip php8.0-xml php8.0-mbstring php8.0-fpm php8.0-cli
    #a2enmod rewrite > /dev/null 2>&1
    cd /tmp

    echo_progress_start "Downloading and extracting Nextcloud"
    codename=$(lsb_release -cs)
    case $codename in
        buster)
            version=latest-23
            ;;
        focal | bullseye)
            version=latest-25
            ;;
        *)
            version=latest
            ;;
    esac
    wget https://download.nextcloud.com/server/releases/${version}.zip >> ${log} 2>&1 || {
        echo_error "Could not download nextcloud"
        exit 1
    }
    unzip ${version}.zip >> ${log} 2>&1
    mv nextcloud /srv
    rm -rf /tmp/${version}.zip
    echo_progress_done "Nextcloud extracted"

  #Set permissions as per nextcloud
  echo_progress_start "Configuring permissions"
  mkdir -p /home/seedit4me/nextcloud
  chown www-data:www-data /home/seedit4me/nextcloud
  chmod 770 /home/seedit4me/nextcloud

    #Set permissions as per nextcloud
    echo_progress_start "Configuring permissions"
  ocpath='/srv/nextcloud'
  htuser='www-data'
  htgroup='www-data'
  rootuser='root'

    mkdir -p $ocpath/data
    mkdir -p $ocpath/assets
    mkdir -p $ocpath/updater
    find ${ocpath}/ -type f -print0 | xargs -0 chmod 0640
    find ${ocpath}/ -type d -print0 | xargs -0 chmod 0750
    chown -R ${rootuser}:${htgroup} ${ocpath}/
    chown -R ${htuser}:${htgroup} ${ocpath}/apps/
    chown -R ${htuser}:${htgroup} ${ocpath}/assets/
    chown -R ${htuser}:${htgroup} ${ocpath}/config/
    chown -R ${htuser}:${htgroup} ${ocpath}/data/
    chown -R ${htuser}:${htgroup} ${ocpath}/themes/
    chown -R ${htuser}:${htgroup} ${ocpath}/updater/
    chmod +x ${ocpath}/occ
    if [ -f ${ocpath}/.htaccess ]; then
        chmod 0644 ${ocpath}/.htaccess
        chown ${rootuser}:${htgroup} ${ocpath}/.htaccess
    fi
    if [ -f ${ocpath}/data/.htaccess ]; then
        chmod 0644 ${ocpath}/data/.htaccess
        chown ${rootuser}:${htgroup} ${ocpath}/data/.htaccess
    fi
    echo_progress_done "Permissions set"

    echo_progress_start "Configuring nginx and php"
    sock="php8.0-fpm"

    cat > /etc/nginx/apps/nextcloud.conf << EOF
# The following 2 rules are only needed for the user_webfinger app.
# Uncomment it if you're planning to use this app.
#rewrite ^/.well-known/host-meta /nextcloud/public.php?service=host-meta last;
#rewrite ^/.well-known/host-meta.json /nextcloud/public.php?service=host-meta-json last;

# The following rule is only needed for the Social app.
# Uncomment it if you're planning to use this app.
#rewrite ^/.well-known/webfinger /nextcloud/public.php?service=webfinger last;

location = /.well-known/carddav {
  return 301 \$scheme://\$host:\$server_port/nextcloud/remote.php/dav;
}
location = /.well-known/caldav {
  return 301 \$scheme://\$host:\$server_port/nextcloud/remote.php/dav;
}

location /.well-known/acme-challenge { }

location ^~ /nextcloud {

    # set max upload size
    client_max_body_size 512M;
    fastcgi_buffers 64 4K;

    # Enable gzip but do not remove ETag headers
    gzip on;
    gzip_vary on;
    gzip_comp_level 4;
    gzip_min_length 256;
    gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
    gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;

    # Uncomment if your server is build with the ngx_pagespeed module
    # This module is currently not supported.
    #pagespeed off;

    location /nextcloud {
        rewrite ^ /nextcloud/index.php;
    }

    location ~ ^\/nextcloud\/(?:build|tests|config|lib|3rdparty|templates|data)\/ {
        deny all;
    }
    location ~ ^\/nextcloud\/(?:\.|autotest|occ|issue|indie|db_|console) {
        deny all;
    }

    location ~ ^\/nextcloud\/(?:index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+)\.php(?:\$|\/) {
        fastcgi_split_path_info ^(.+?\.php)(\/.*|)\$;
        set \$path_info \$fastcgi_path_info;
        try_files \$fastcgi_script_name =404;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$path_info;
        fastcgi_param HTTPS on;
        # Avoid sending the security headers twice
        fastcgi_param modHeadersAvailable true;
        # Enable pretty urls
        fastcgi_param front_controller_active true;
        fastcgi_pass unix:/run/php/$sock.sock;
        fastcgi_intercept_errors on;
        fastcgi_request_buffering off;
    }

    location ~ ^\/nextcloud\/(?:updater|oc[ms]-provider)(?:\$|\/) {
        try_files \$uri/ =404;
        index index.php;
    }

    # Adding the cache control header for js, css and map files
    # Make sure it is BELOW the PHP block
    location ~ ^\/nextcloud\/.+[^\/]\.(?:css|js|woff2?|svg|gif|map)\$ {
        try_files \$uri /nextcloud/index.php\$request_uri;
        add_header Cache-Control "public, max-age=15778463";
        # Add headers to serve security related headers  (It is intended
        # to have those duplicated to the ones above)
        # Before enabling Strict-Transport-Security headers please read
        # into this topic first.
        #add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;" always;
        #
        # WARNING: Only add the preload option once you read about
        # the consequences in https://hstspreload.org/. This option
        # will add the domain to a hardcoded list that is shipped
        # in all major browsers and getting removed from this list
        # could take several months.
        add_header Referrer-Policy "no-referrer" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Download-Options "noopen" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Permitted-Cross-Domain-Policies "none" always;
        add_header X-Robots-Tag "none" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Optional: Don't log access to assets
        access_log off;
    }

    location ~ ^\/nextcloud\/.+[^\/]\.(?:png|html|ttf|ico|jpg|jpeg|bcmap)\$ {
        try_files \$uri /nextcloud/index.php\$request_uri;
        # Optional: Don't log access to other assets
        access_log off;
    }
}
EOF
    echo_progress_done

    echo_progress_start "Configuring database"
    mysql --user="root" --password="$password" --execute="CREATE DATABASE nextcloud;"
    mysql --user="root" --password="$password" --execute="CREATE USER nextcloud@localhost IDENTIFIED BY '$nextpass';"
    mysql --user="root" --password="$password" --execute="GRANT ALL PRIVILEGES ON nextcloud.* TO nextcloud@localhost;"
    mysql --user="root" --password="$password" --execute="FLUSH PRIVILEGES;"
    echo_progress_done "Database configured"

	cd $ocpath
	sudo -u www-data php occ maintenance:install --no-interaction --data-dir "/home/seedit4me/nextcloud" --database "mysql" --database-name "nextcloud" --database-user "nextcloud" --database-pass "${nextpass}" --admin-user "${user}" --admin-pass "${nextpass}"
	sudo -u www-data php occ config:system:set trusted_domains 1 --value=*.seedit4.me
	. /etc/swizzin/sources/functions/php
	restart_php_fpm

    echo_progress_start "Restarting nginx"
    systemctl reload nginx
    echo_progress_start "nginx restarted"

    touch /install/.nextcloud.lock
    echo_success "Nextcloud installed"

fi
