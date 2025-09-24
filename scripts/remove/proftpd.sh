#!/bin/bash

apt_remove proftpd proftpd-basic >> "${log}" 2>&1
rm -rf /etc/proftpd/
rm /install/.proftpd.lock


