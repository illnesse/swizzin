#!/bin/bash

if [[ -f /tmp/rutorrent_errors.log ]]; then
    if grep -q "public tracker" /tmp/rutorrent_errors.log; then

        pass=$(cut -d: -f2 < /root/.master.info)
        hostname="$(cat /proc/sys/kernel/hostname)"
        hostname="${hostname/ct/}"
        slackurl="https://hooks.dudewtf/services/TLKMV1Z3R/BQM2PJ2SG/cddPy3W3ILDmQK0brEUQTf2U"
        slackurl="${slackurl/dudewtf/slack.com}"
        dashurl="https://my.seedit4.me/api/trackers/report"

        curl -X POST -H 'Content-type: application/json' --data "$(
            cat << EOF
{
"text": "<https://my.seedit4.me/boxes/$hostname|$hostname> : public torrent detected."
}
EOF
        )" $slackurl

        rm /tmp/rutorrent_errors.log

        curl -X POST -H 'Content-type: application/json' --data "$(
            cat << EOF
{
"public": "true",
"hostname": "$hostname",
"pass": "$pass"
}
EOF
        )" $dashurl

    fi
fi
