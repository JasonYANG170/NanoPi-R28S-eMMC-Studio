#!/bin/sh
set -eu
[ "$(id -u)" = 0 ] || { echo '请使用 sudo 运行。' >&2; exit 1; }
if [ -e /var/lib/emmc-web/auth.json ]; then
    rm -f /root/emmc-studio-setup.txt
    echo '管理员已初始化；本命令不会重置管理员密码。'
    exit 0
fi
case "${1:-}" in
    '') ;;
    --reset)
        # Only rotates the setup code while no administrator exists.
        systemctl stop emmc-web
        rm -f /var/lib/emmc-web/setup.hash /root/emmc-studio-setup.txt
        /usr/local/sbin/emmc-studio-firstboot
        systemctl start emmc-web
        exit 0
        ;;
    *) echo '用法：sudo emmc-studio-setup-code [--reset]' >&2; exit 2 ;;
esac
[ -f /root/emmc-studio-setup.txt ] || { echo '首次启动未完成，请检查 emmc-studio-firstboot 服务。' >&2; exit 1; }
cat /root/emmc-studio-setup.txt
