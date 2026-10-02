#!/bin/bash
# Executed by Armbian inside the image's chroot, not on the host.
set -euo pipefail
[[ "${1:-}" == trixie && "${3:-}" == nanopi-r28s && "${5:-}" == arm64 ]]
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends python3-flask python3-waitress \
    parted gdisk dosfstools exfatprogs ntfs-3g e2fsprogs mmc-utils psmisc util-linux curl
python3 -c 'import flask, waitress'
for tool in lsblk blockdev sfdisk partprobe sgdisk mkfs.ext4 e2fsck resize2fs mkfs.vfat mkfs.exfat mkfs.ntfs mmc fuser; do
    command -v "$tool" >/dev/null
done
getent group emmc-web >/dev/null || groupadd --system emmc-web
getent passwd emmc-web >/dev/null || useradd --system --gid emmc-web \
    --home /var/lib/emmc-web --shell /usr/sbin/nologin emmc-web
install -d -m 0755 /opt/emmc-studio
cp -a /tmp/overlay/emmc-studio/. /opt/emmc-studio/
chown -R root:root /opt/emmc-studio
chmod -R go-w /opt/emmc-studio
install -d -o emmc-web -g emmc-web -m 0750 \
    /var/lib/emmc-web /var/lib/emmc-web/uploads /var/lib/emmc-web/downloads
install -d -o root -g emmc-web -m 0750 /var/lib/emmc-worker
install -m 0644 /opt/emmc-studio/deploy/emmc-web.service /etc/systemd/system/
install -m 0644 /opt/emmc-studio/deploy/emmc-worker.service /etc/systemd/system/
install -m 0644 /tmp/overlay/emmc-studio-firstboot.service /etc/systemd/system/
install -m 0755 /tmp/overlay/emmc-studio-firstboot.sh /usr/local/sbin/emmc-studio-firstboot
install -m 0755 /tmp/overlay/emmc-studio-setup-code.sh /usr/local/sbin/emmc-studio-setup-code
install -d -m 0755 /etc/systemd/system/emmc-web.service.d
install -m 0644 /tmp/overlay/emmc-web-firstboot.conf /etc/systemd/system/emmc-web.service.d/firstboot.conf
install -m 0644 /tmp/overlay/build-info.json /etc/emmc-studio-build.json
systemctl --no-reload enable emmc-studio-firstboot.service emmc-worker.service emmc-web.service
# Never generate credentials, sessions or disk task state in a distributed image.
for path in auth.json setup.hash session.key; do
    [[ ! -e "/var/lib/emmc-web/$path" ]]
done
[[ ! -e /root/emmc-studio-setup.txt ]]
python3 -m compileall -q /opt/emmc-studio/backend /opt/emmc-studio/deploy
apt-get clean
echo 'eMMC Studio embedded; credentials will be generated on the device at first boot.'
