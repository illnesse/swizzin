#!/bin/bash
# Sonarr v4 installer
# Flying sauasges for swizzin 2020

#shellcheck source=sources/functions/utils
. /etc/swizzin/sources/functions/utils

if [[ -z $sonarrv4owner ]]; then
    sonarrv4owner=$(_get_master_username)
fi

sonarrv4confdir="/home/$sonarrv4owner/.config/Sonarr"

_install_sonarr() {
    #shellcheck source=sources/functions/mono
    # . /etc/swizzin/sources/functions/mono
    # mono_repo_setup
    mkdir -p "$sonarrv4confdir"
    chown -R "$sonarrv4owner":"$sonarrv4owner" /home/"$sonarrv4owner"/.config

    echo_log_only "Setting sonarr v4 owner to $sonarrv4owner"
    wget -O /tmp/sonarr.tar.gz "https://services.sonarr.tv/v1/download/develop/latest?version=4&os=linux&arch=x64" >> ${log} 2>&1 || {
        echo_error "Sonarr could not be downloaded from sonarr.tv. Exiting"
        exit 1
    }
    tar xf /tmp/sonarr.tar.gz -C /opt >> ${log} 2>&1 || {
        echo_error "Failed to extract archive"
        exit 1
    }
    rm -f /tmp/sonarr.tar.gz
    chown -R "$sonarrv4owner":"$sonarrv4owner" /opt/Sonarr

    LIST='curl
        sqlite3'
    # LIST='mono-runtime
    #     ca-certificates-mono
    #     libmono-system-net-http4.0-cil
    #     libmono-corlib4.5-cil
    #     libmono-microsoft-csharp4.0-cil
    #     libmono-posix4.0-cil
    #     libmono-system-componentmodel-dataannotations4.0-cil
    #     libmono-system-configuration-install4.0-cil
    #     libmono-system-configuration4.0-cil
    #     libmono-system-core4.0-cil
    #     libmono-system-data-datasetextensions4.0-cil
    #     libmono-system-data4.0-cil
    #     libmono-system-identitymodel4.0-cil
    #     libmono-system-io-compression4.0-cil
    #     libmono-system-numerics4.0-cil
    #     libmono-system-runtime-serialization4.0-cil
    #     libmono-system-security4.0-cil
    #     libmono-system-servicemodel4.0a-cil
    #     libmono-system-serviceprocess4.0-cil
    #     libmono-system-transactions4.0-cil
    #     libmono-system-web4.0-cil
    #     libmono-system-xml-linq4.0-cil
    #     libmono-system-xml4.0-cil
    #     libmono-system4.0-cil
    #     sqlite3
    #     mediainfo'

    apt_install ${LIST}

    cat > /etc/systemd/system/sonarr.service << EOSD
[Unit]
Description=Sonarr Daemon
After=network.target

[Service]
User=${sonarrv4owner}
Group=${sonarrv4owner}
UMask=0002

Type=simple
ExecStart=/opt/Sonarr/Sonarr -nobrowser -data=${sonarrv4confdir}
TimeoutStopSec=20
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOSD

    if [[ ! -f ${sonarrv4confdir}/config.xml ]]; then
        cat > ${sonarrv4confdir}/config.xml << EOSC
<Config>
  <LogLevel>info</LogLevel>
  <EnableSsl>False</EnableSsl>
  <Port>8989</Port>
  <SslPort>9898</SslPort>
  <UrlBase></UrlBase>
  <BindAddress>*</BindAddress>
  <AuthenticationMethod>None</AuthenticationMethod>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <Branch>main</Branch>
</Config>
EOSC
        chown -R ${sonarrv4owner}: ${sonarrv4confdir}/config.xml
    fi
    systemctl enable --now sonarr >> ${log} 2>&1

    touch /install/.sonarr4.lock
}

# _add2usergroups_sonarrv4 () {
#         if [[ -z $sonarrv4grouplist ]]; then
#             if ask "Do you want to let Sonarr access other users' home directories?" N; then
#                 echo "Space separated list of users to give sonarr access to: (e.g. \"user1 user2\")"
#                 read -r sonarrv4grouplist
#             fi
#         fi
#         if [[ -n $sonarrv4grouplist ]]; then
#             for u in $sonarrv4grouplist; do
#                 echo "Adding ${sonarrv4owner} to $u's group"
#                 usermod -a -G "$u" "$sonarrv4owner"
#                 chmod g+rwx /home/"$u"
#             done
#         fi
# }

_nginx_sonarr() {
    if [[ -f /install/.nginx.lock ]]; then
        #TODO what is this sleep here for? See if this can be fixed by doing a check for whatever it needs to
        echo_progress_start "Installing nginx configuration"
        bash /usr/local/bin/swizzin/nginx/sonarr.sh
        systemctl reload nginx >> "$log" 2>&1
        echo_progress_done
    else
        echo_info "Sonarr will run on port 8989"
    fi
}

_install_sonarr
_nginx_sonarr

touch /install/.sonarr4.lock

if [[ -f /install/.ombi.lock ]]; then
    echo_info "Please adjust your Ombi setup accordingly"
fi

if [[ -f /install/.tautulli.lock ]]; then
    echo_info "Please adjust your Tautulli setup accordingly"
fi

if [[ -f /install/.bazarr.lock ]]; then
    echo_info "Please adjust your Bazarr setup accordingly"
fi

echo_success "Sonarr v4 installed"
