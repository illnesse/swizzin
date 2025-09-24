#!/bin/bash

if [[ ! -f /usr/local/bin/rar2fs ]]; then
  echo_progress_start "Installing dependencies"
  apt_install libfuse-dev autoconf g++ make
  echo_progress_done

  echo_progress_start "downloading & compiling unrar source"
  mkdir -p /tmp/rar2fs
  cd /tmp/rar2fs
  wget https://www.rarlab.com/rar/unrarsrc-6.0.4.tar.gz
  tar xzf unrarsrc-6.0.4.tar.gz
  cd unrar
  make lib >> "${log}" 2>&1
  sudo make install-lib >> "${log}" 2>&1
  echo_progress_done

  echo_progress_start "downloading & compiling rar2fs source"
  cd /tmp/rar2fs
  wget https://github.com/hasse69/rar2fs/releases/download/v1.29.4/rar2fs-1.29.4.tar.gz
  tar -xzf rar2fs-1.29.4.tar.gz
  cd rar2fs-1.29.4
  cp /usr/include/fuse/fuse_common.h ./src/
  cp /usr/include/fuse/fuse_opt.h ./src/
  ./configure --with-unrar="../unrar" >> "${log}" 2>&1
  make >> "${log}" 2>&1
  sudo make install >> "${log}" 2>&1
  sudo ln -s /usr/local/bin/rar2fs /bin/rar2fs
  echo_progress_done

  rm -rf /tmp/rar2fs

  mkdir -p /home/seedit4me/rar2fsmount/torrents
else
  echo_log_only "rar2fs binary already exists"
fi

echo_progress_start "Configuring systemd service"
cat > /usr/local/bin/mountrar2fs.sh << R2FS
#!/bin/bash
# script to mount rar2fs mounts

rar2fs -o allow_other --seek-length=0 /home/seedit4me/torrents /home/seedit4me/rar2fsmount/torrents

exit 0
R2FS

sudo chmod +x /usr/local/bin/mountrar2fs.sh

cat > /etc/systemd/system/mountrar2fs.service << R2FSSVC
[Unit]
Description=mountrar2fs
After=network.target

[Service]

Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/bin/bash /usr/local/bin/mountrar2fs.sh
RemainAfterExit=yes

[Install]
WantedBy=default.target
R2FSSVC
echo_progress_done

systemctl enable -q --now mountrar2fs 2>&1 | tee -a $log
echo_progress_done "started rar2fs service"

echo_info "mounting /home/seedit4me/torrents to"
echo_info "/home/seedit4me/rar2fsmount/torrents"

echo_success "rar2fs installed"
touch /install/.rar2fs.lock
