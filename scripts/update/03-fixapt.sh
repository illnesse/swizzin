#!/bin/bash

echo_progress_start "temp fix apt repos"

add-apt-repository -y --remove ppa:ondrej/nginx-mainline
add-apt-repository -y ppa:ondrej/nginx

apt-get update -y --allow-releaseinfo-change

echo_progress_done "done"
