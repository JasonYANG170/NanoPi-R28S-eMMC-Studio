#!/bin/bash
# Credential lifecycle test in a disposable container, never on a real device.
set -euo pipefail
docker run --rm \
    -v "$PWD/studio:/opt/emmc-studio:ro" \
    -v "$PWD/userpatches/overlay:/overlay:ro" \
    debian:trixie bash -euc '
        apt-get update -qq
        apt-get install -y --no-install-recommends python3 >/dev/null
        groupadd --system emmc-web
        useradd --system --gid emmc-web emmc-web
        install -d -o emmc-web -g emmc-web -m 0750 /var/lib/emmc-web
        sh /overlay/emmc-studio-firstboot.sh > /tmp/first.log
        test -s /var/lib/emmc-web/setup.hash
        test -s /root/emmc-studio-setup.txt
        test ! -e /var/lib/emmc-web/auth.json
        test "$(stat -c %a /root/emmc-studio-setup.txt)" = 600
        test "$(stat -c %a /var/lib/emmc-web/setup.hash)" = 600
        cp /var/lib/emmc-web/setup.hash /tmp/original.hash
        sh /overlay/emmc-studio-firstboot.sh > /tmp/second.log
        cmp /tmp/original.hash /var/lib/emmc-web/setup.hash
        touch /var/lib/emmc-web/auth.json
        sh /overlay/emmc-studio-firstboot.sh
        test ! -e /root/emmc-studio-setup.txt
        cmp /tmp/original.hash /var/lib/emmc-web/setup.hash
        echo "PASS: unique setup at runtime, preserved across boots, retired after setup."
    '
