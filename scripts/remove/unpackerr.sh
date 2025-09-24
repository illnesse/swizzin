#!/bin/bash

apt_remove unpackerr
deluser unpackerr --system --quiet

rm /etc/apt/sources.list.d/golift.list
rm /install/.unpackerr.lock
