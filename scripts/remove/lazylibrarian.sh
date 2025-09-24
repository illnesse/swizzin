#!/bin/bash

#!/bin/bash
user=$(cut -d: -f1 < /root/.master.info)
systemctl disable --now -q lazylibrarian

rm -rf /opt/lazylibrarian
rm -rf /opt/.venv/lazylibrarian
if [ -z "$(ls -A /opt/.venv)" ]; then
    rm -rf /opt/.venv
fi
rm -rf /etc/nginx/apps/lazylibrarian.conf
rm -rf /install/.lazylibrarian.lock
rm -rf /etc/systemd/system/lazylibrarian.service
systemctl reload nginx
