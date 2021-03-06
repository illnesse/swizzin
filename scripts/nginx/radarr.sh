#!/bin/bash
# Nginx conf for Radarr v3
# Flying sausages 2020
master=$(cut -d: -f1 < /root/.master.info)
password="$(cut -d: -f2 < /root/.master.info)"

cat > /etc/nginx/apps/radarr.conf << RADARR
location /radarr {
  proxy_pass        http://127.0.0.1:7878/radarr;
  proxy_set_header Host \$proxy_host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_redirect off;
  auth_basic "What's the password?";
  auth_basic_user_file /etc/htpasswd.d/htpasswd.${master};

  proxy_http_version 1.1;
  proxy_set_header Upgrade \$http_upgrade;
  proxy_set_header Connection \$http_connection;
  proxy_cache_bypass \$http_upgrade;
  proxy_buffering off;
}
RADARR

isactive=$(systemctl is-active radarr)

if [[ $isactive == "active" ]]; then
	systemctl stop radarr
fi
user=$(grep User /etc/systemd/system/radarr.service | cut -d= -f2)
echo "Radarr user detected as $user"
apikey=$(awk -F '[<>]' '/ApiKey/{print $3}' /home/"$user"/.config/Radarr/config.xml)
echo "API Key  = $apikey" >> "$log"
#TODO cahnge Branch whenever that becomes relevant
cat > /home/"$user"/.config/Radarr/config.xml << SONN
<Config>
  <LogLevel>info</LogLevel>
  <UpdateMechanism>BuiltIn</UpdateMechanism>
  <BindAddress>127.0.0.1</BindAddress>
  <Port>7878</Port>
  <SslPort>8787</SslPort>
  <EnableSsl>False</EnableSsl>
  <LaunchBrowser>False</LaunchBrowser>
  <ApiKey>${apikey}</ApiKey>
  <AuthenticationMethod>None</AuthenticationMethod>
  <UrlBase>radarr</UrlBase>
</Config>
SONN

chown -R "$user":"$user" /home/"$user"/.config/Radarr

systemctl start radarr -q # Switch radarr on regardless whether it was off before or not as we need to have it online to trigger this cahnge

sleep 5 # TODO replace with a loop until the API is available
payload="$(curl -s "https://127.0.0.1/radarr/api/v3/config/host?apiKey=${apikey}" \
	--user "${user}:${password}" --insecure \
	-s | \
	jq '.certificateValidation = "disabledForLocalAddresses"')"
echo  "Payload = \n${payload}"
echo  "Return from radarr after PUT ="
curl "https://127.0.0.1/radarr/api/v3/config/host?apiKey=${apikey}" -X PUT --insecure \
	-H 'Accept: application/json, text/javascript, */*; q=0.01' \
	--compressed -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
	--user "${user}:${password}" \
	--data-raw "$payload" -s >> "$log"

curl -v -s "https://127.0.0.1/radarr/api/v3/config/host?apiKey=6eecd3ffbaa5415a8137d3e658938ef2" --user "seedit4me:jpop99" --insecure -s | jq '.certificateValidation = "disabledForLocalAddresses"'

# Switch radarr back off if it was dead before
if [[ $isactive != "active" ]]; then
	systemctl stop radarr
fi
