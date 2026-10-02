#!/bin/bash
# Inspect a generated image read-only, including its separate boot partition.
set -euo pipefail
image=$(realpath "$1")
[[ -f "$image" && "$image" == *.img ]]
work=$(mktemp -d)
loop=''
cleanup() {
    set +e
    mountpoint -q "$work/root" && umount "$work/root"
    mountpoint -q "$work/boot" && umount "$work/boot"
    [[ -z "$loop" ]] || losetup -d "$loop"
    rm -rf "$work"
}
trap cleanup EXIT
loop=$(losetup --find --show --read-only --partscan "$image")
udevadm settle
mkdir "$work/root" "$work/boot"
mount -o ro,noload "${loop}p2" "$work/root"
mount -o ro,noload "${loop}p1" "$work/boot"
root="$work/root"
for file in etc/os-release etc/emmc-studio-build.json opt/emmc-studio/dist/index.html \
    opt/emmc-studio/backend/web.py opt/emmc-studio/backend/worker.py \
    etc/systemd/system/emmc-web.service.d/firstboot.conf \
    usr/local/sbin/emmc-studio-firstboot usr/local/sbin/emmc-studio-setup-code; do
    test -s "$root/$file"
done
for service in emmc-web emmc-worker emmc-studio-firstboot; do
    test -L "$root/etc/systemd/system/multi-user.target.wants/$service.service"
done
for file in auth.json setup.hash session.key; do
    test ! -e "$root/var/lib/emmc-web/$file"
done
test ! -e "$root/root/emmc-studio-setup.txt"
test -s "$work/boot/boot.scr"
test -e "$work/boot/uInitrd"
# Resolve absolute links relative to the mounted boot partition.
initrd="$work/boot/uInitrd"
if [[ -L "$initrd" ]]; then
    link=$(readlink "$initrd")
    initrd="$work/boot/${link#/boot/}"
fi
python3 - "$initrd" "$root/etc/emmc-studio-build.json" <<'PY'
import json, sys
from pathlib import Path
assert Path(sys.argv[1]).read_bytes()[:4] == bytes.fromhex('27051956'), 'uInitrd has no U-Boot legacy header'
info = json.loads(Path(sys.argv[2]).read_text())
assert info['board'] == 'nanopi-r28s' and info['branch'] == 'vendor'
print(json.dumps(info, indent=2))
PY
echo 'PASS: image contains eMMC Studio, enabled services and valid U-Boot initramfs; no shared credentials.'
