#!/bin/bash
cp /srv/tools/logs/output.log /srv/tools/logs/output_$(date +%F-%H_%M_%S).log
sleep 1s
rm /srv/tools/logs/output.log
touch /srv/tools/logs/output.log
chmod 777 /srv/tools/logs/output.log
