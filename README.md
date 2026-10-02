# NanoPi R28S · eMMC Studio 固件

基于 [Armbian NanoPi R28S](https://armbian.com/boards/nanopi-r28s) 的 Debian 13 trixie / vendor / minimal CLI 固件，预装 [eMMC Studio](https://github.com/JasonYANG170/eMMC-Studio)。在 GitHub Actions 中使用 Armbian 官方构建框架生成完整启动镜像，包含内核、U-Boot、设备树和预装网页。

**下载：[Releases](https://github.com/JasonYANG170/NanoPi-R28S-eMMC-Studio/releases/latest)** · **构建：[Actions](https://github.com/JasonYANG170/NanoPi-R28S-eMMC-Studio/actions/workflows/firmware.yml)**

网页监听 `0.0.0.0:80`，访问 `http://<设备IP>/`。支持 eMMC 用户区、BOOT0/BOOT1、分区、文件、十六进制编辑、USB 克隆、流式下载、备份恢复、设备信息及深浅色主题。详细功能与操作边界见 [eMMC Studio 文档](https://github.com/JasonYANG170/eMMC-Studio#readme)。

## 下载与刷写

1. 下载 Release 中的 `NanoPi-R28S-eMMC-Studio-*.img.xz` 和 `SHA256SUMS`。
2. 校验文件。Linux 可运行 `sha256sum -c SHA256SUMS --ignore-missing`；Windows PowerShell 使用 `Get-FileHash .\NanoPi-R28S-eMMC-Studio-*.img.xz -Algorithm SHA256`，与 `SHA256SUMS` 中镜像的值比较。
3. 使用 [Armbian Imager](https://imager.armbian.com/) 或 balenaEtcher 把镜像写入 **SD 卡**。刷写会清空所选 SD 卡，请确认目标。
4. NanoPi R28S 插入 SD 卡，接入有 DHCP 的局域网并通电。首次启动可能需要几分钟完成系统盘扩容及系统初始化。
5. 在路由器 DHCP 列表中查找设备，或通过串口登录后执行 `hostname -I`。本固件主机名为 `emmc-studio`，IP 由网络分配，没有固定 IP。

推荐从 SD 卡启动，让 eMMC 保持为被管理的存储。若将系统装到 eMMC，eMMC 会成为系统盘并被禁止破坏性修改，不适合整盘读卡器用途。固件不会自动刷写、格式化或恢复 eMMC，也不改变 OTG Gadget 配置。

板级启动配置沿用上游 `nanopi-r28s.csc`，包括 GPT、512 MiB ext4 启动分区和 `rk3528-nanopi-rev03.dtb`。本镜像用于 NanoPi R28S，其他 RK3528 板卡应使用其自身的板级配置。

## 首次登录与网页初始化

Armbian 系统登录遵循其 [首次登录流程](https://docs.armbian.com/os/getting-started/first-boot/)；系统账号与网页管理员是两个独立账号。串口参数请采用 NanoPi R28S 的板卡说明。

eMMC Studio 在首次启动时生成独立一次性设置码，不在 CI 或发布镜像中生成密码。系统登录后执行：

```sh
sudo emmc-studio-setup-code
```

浏览器访问 `http://<设备IP>/`，填写设置码并创建 `emmc-admin` 管理员密码。密码长度 8–128 字符，由加盐 scrypt 保存；无固定网页密码。设置码记录在本机 root 专属的 `/root/emmc-studio-setup.txt`，权限 0600，也会输出到首次启动控制台和本机服务日志。创建管理员后的下一次启动会删除该提示文件。

管理员尚未创建时，可以重新生成设置码：

```sh
sudo emmc-studio-setup-code --reset
```

该命令只允许轮换未使用的设置码，不会重置已有管理员密码。正常使用时只在受信任的局域网开放此管理网页。

## GitHub Actions 构建

仓库 `main` 中构建配置、源码锁定或脚本发生变化时自动构建。手动构建：打开 **Actions → Build NanoPi R28S eMMC Studio firmware → Run workflow**。无需个人 Token，发布作业使用仓库的 `GITHUB_TOKEN`。

CI 流程：

1. 从 `sources.json` 读取并检出固定的 Armbian 框架与 eMMC Studio 提交。
2. 在 Node.js 22 环境构建并测试网页，将发布文件放入 Armbian overlay。
3. 检查 Shell 脚本，在临时 Debian 容器中验证首次启动设置码生命周期。
4. 通过 Armbian 构建框架和 Docker 编译完整固件。
5. 只读挂载成品，检查预装文件、服务启用、无共用凭据及 U-Boot initramfs 头。
6. 压缩为 `.img.xz`，附 SHA-256、源码版本和检查报告，成功后发布到 Release。失败不发布镜像，构建日志保存到 Actions artifacts。

构建耗时取决于源码下载、上游缓存及编译负载；任务最长 350 分钟。拉取请求只做脚本检查，不执行有发布权限的构建。Release 标签包含日期与运行编号，历史镜像保留。

`sources.json` 固定框架与应用提交；Debian 包仓库、Armbian 缓存和框架中引用的内核来源仍可能更新，因此不声称镜像逐字节可复现。每次构建的源码提交保存在 Release 的 `build-info.json` 和镜像内 `/etc/emmc-studio-build.json`。

## 本地构建

需要 Linux、可使用的 Docker、至少 8 GiB 内存及约 50 GiB 可用空间，详见 [Armbian 构建要求](https://docs.armbian.com/build-framework/getting-started/)。建议给编译提供更多磁盘空间。Windows 可使用 WSL2 Linux 环境，构建路径不要包含空格。

```sh
git clone https://github.com/JasonYANG170/NanoPi-R28S-eMMC-Studio.git
cd NanoPi-R28S-eMMC-Studio

git clone https://github.com/armbian/build.git build
git -C build checkout "$(python3 -c 'import json; print(json.load(open("sources.json"))["armbian"]["commit"])')"
git clone https://github.com/JasonYANG170/eMMC-Studio.git studio
git -C studio checkout "$(python3 -c 'import json; print(json.load(open("sources.json"))["studio"]["commit"])')"

# 电脑端需预先安装 Node.js 22 和 npm。
(cd studio && npm ci && npm run test:frontend && npm run build)
python3 scripts/prepare.py
bash scripts/test-bootstrap.sh
(cd build && ./compile.sh build emmc-studio PREFER_DOCKER=yes SHOW_LOG=yes)
sudo bash scripts/verify-image.sh build/output/images/*.img
```

本地输出为 `build/output/images/*.img`，可自行使用 `xz -T2 -6` 压缩。`prepare.py` 要求干净的 overlay，重复构建请使用新的仓库工作目录。预装使用 [Armbian customize-image/overlay 机制](https://docs.armbian.com/build-framework/user-configurations/)，无需修改官方框架。

## 服务与故障排查

```sh
systemctl status emmc-studio-firstboot emmc-worker emmc-web
sudo journalctl -u emmc-studio-firstboot -u emmc-worker -u emmc-web -b
hostname -I
curl http://127.0.0.1/api/v1/auth/status
cat /etc/emmc-studio-build.json
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,RO
```

网页由普通用户 `emmc-web` 提供，只有绑定 80 端口的能力；root 工作进程通过 Unix socket 执行受限磁盘操作。两项应用服务异常自动重启，并在开机时自动启动。

浏览器访问失败时，先检查设备 DHCP 地址、80 端口和三个服务。eMMC 识别失败时检查 `lsblk`、MMC 内核日志与真实硬件连接，不要依据设备编号强制写入。系统 SD 卡自动识别并保护；BOOT 区软件只读保护在写入任务结束后恢复。

## 更新与卸载 eMMC Studio

单独更新网页应用，保留管理员与状态：

```sh
curl -fL https://raw.githubusercontent.com/JasonYANG170/eMMC-Studio/main/install.sh -o /tmp/emmc-studio-install.sh
sudo sh /tmp/emmc-studio-install.sh
```

卸载网页应用：

```sh
sudo systemctl disable --now emmc-studio-firstboot.service
sudo rm -f /etc/systemd/system/emmc-web.service.d/firstboot.conf
sudo sh /opt/emmc-studio/deploy/uninstall.sh
sudo systemctl daemon-reload
```

卸载默认保留管理员、备份和任务数据。固件系统本身的重新刷写是另一项操作，会清空刷写目标。

## 验证范围

CI 验证构建、预装文件、首次启动凭据流程、服务启用和镜像启动文件格式。CI 不含 NanoPi R28S 真机，因此不能替代串口启动、网络、eMMC/BOOT 读取以及 USB 实物测试。发布的检查报告说明实际完成的检查，不将成功编译等同于真机验收。

Armbian 标记该板为 Community。上游内核、U-Boot、固件及 eMMC Studio 的源码和授权要求见各自仓库，本仓库不改变其许可证。
