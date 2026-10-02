预装 eMMC Studio 的 NanoPi R28S Armbian 固件，Debian 13 trixie / vendor 内核 / minimal CLI。

下载 `.img.xz` 和 `SHA256SUMS`，核对 SHA-256 后刷入 **SD 卡**，插卡启动。连接有 DHCP 的局域网，网页地址为 `http://<设备IP>/`，80 端口自动启动。

首次启动在设备本机生成独立管理员设置码。完成 Armbian 系统首次登录后，执行 `sudo emmc-studio-setup-code`，用该码在网页创建管理员密码（8–128 字符）。固件不包含共用的网页密码、设置码或会话密钥。

系统 SD 卡作为受保护的系统盘；eMMC 作为被管理存储，启动后不会自动覆盖 eMMC 或 BOOT 区。请阅读仓库 README 的刷写、初始化及故障排查说明。

`build-info.json` 记录固定源码提交；`verification.txt` 为成品镜像只读检查结果。CI 检查不等同于真机启动验收，首次使用请通过串口确认本板启动与 eMMC 识别。
