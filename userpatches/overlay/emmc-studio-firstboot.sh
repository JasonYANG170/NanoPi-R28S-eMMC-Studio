#!/bin/sh
set -eu
umask 077
state=/var/lib/emmc-web
code_file=/root/emmc-studio-setup.txt
if [ -e "$state/auth.json" ]; then
    rm -f "$code_file"
    exit 0
fi
if [ ! -e "$state/setup.hash" ]; then
    python3 /opt/emmc-studio/deploy/initialize.py > "$code_file"
    chmod 0600 "$code_file"
fi
if [ -f "$code_file" ]; then
    cat "$code_file"
    echo '访问 http://<设备IP>/；再次查看设置码：sudo emmc-studio-setup-code'
else
    echo '设置码已存在。请使用原设置码，或在本机运行 sudo emmc-studio-setup-code --reset。'
fi
