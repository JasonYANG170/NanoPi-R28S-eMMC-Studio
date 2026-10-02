[简体中文](README.md) | [English](README_en.md)

# NanoPi R28S · eMMC Studio Firmware

Debian 13 trixie / vendor / minimal CLI firmware based on [Armbian NanoPi R28S](https://armbian.com/boards/nanopi-r28s), with [eMMC Studio](https://github.com/JasonYANG170/eMMC-Studio) preinstalled. GitHub Actions uses the official Armbian build framework to create a complete bootable image containing the kernel, U-Boot, device tree, and preinstalled web application.

**Download: [Releases](https://github.com/JasonYANG170/NanoPi-R28S-eMMC-Studio/releases/latest)** ·**Build: [Actions](https://github.com/JasonYANG170/NanoPi-R28S-eMMC-Studio/actions/workflows/firmware.yml)**

The web interface listens on `0.0.0.0:80`; open `http://<device-IP>/`. Supports the eMMC user area, BOOT0/BOOT1, partitions, files, hexadecimal editing, USB cloning, streaming downloads, backup and recovery, device information, and light/dark themes. See the [eMMC Studio documentation](https://github.com/JasonYANG170/eMMC-Studio#readme) for details and operating limits.

## Downloading and flashing

1. Download `NanoPi-R28S-eMMC-Studio-*.img.xz` and `SHA256SUMS` from the release.
2. Verify the image. On Linux, run `sha256sum -c SHA256SUMS --ignore-missing`. In Windows PowerShell, run `Get-FileHash .\NanoPi-R28S-eMMC-Studio-*.img.xz -Algorithm SHA256` and compare the result with the image checksum in `SHA256SUMS`.
3. Use [Armbian Imager](https://imager.armbian.com/) or balenaEtcher to write the image to an **SD card**. Flashing erases the selected SD card, so verify the target.
4. Insert the SD card into NanoPi R28S, connect it to a LAN with DHCP, and power it on. The first boot may take several minutes to expand the system partition and initialize the system.
5. Find the device in the router's DHCP list, or log in over serial and run `hostname -I`. The firmware hostname is `emmc-studio`. The network assigns its IP; there is no fixed IP address.

Booting from SD is recommended so eMMC remains available as managed storage. If the system is installed on eMMC, eMMC becomes the protected system disk and cannot undergo destructive modification, making it unsuitable for whole-disk reader use. The firmware does not automatically flash, format, or recover eMMC, or change OTG Gadget configuration.

Board boot settings follow upstream `nanopi-r28s.csc`, including GPT, a 512 MiB ext4 boot partition, and `rk3528-nanopi-rev03.dtb`. This image is for NanoPi R28S; other RK3528 boards need their own board configuration.

## First login and web initialization

Armbian system login follows its [first-login procedure](https://docs.armbian.com/getting-started/first-boot-and-login/). The system account and web administrator are separate accounts. The first SSH login uses `root` / `1234`; follow the prompts to change the password and create a regular user. Use the serial settings documented for NanoPi R28S.

eMMC Studio generates a separate one-time setup code on first boot. Passwords are not generated in CI or embedded in the released image. After system login, run:

```sh
sudo emmc-studio-setup-code
```

Open `http://<device-IP>/`, enter the setup code, and create an `emmc-admin` password. Passwords contain 8–128 characters and are stored with salted scrypt; there is no fixed web password. The setup code is recorded in root-only `/root/emmc-studio-setup.txt` with permissions 0600 and printed to the first-boot console and local service logs. The hint file is deleted on the next boot after administrator creation.

Before an administrator is created, you can regenerate the setup code:

```sh
sudo emmc-studio-setup-code --reset
```

This command rotates only an unused setup code; it does not reset an existing administrator password. Expose this management interface only on a trusted LAN during normal use.

## GitHub Actions builds

Builds run automatically when configuration, source locks, or scripts change on `main`. To build manually, open **Actions → Build NanoPi R28S eMMC Studio firmware → Run workflow**. No personal token is required; publishing uses the repository's `GITHUB_TOKEN`.

CI workflow:

1. Read `sources.json` and check out pinned Armbian framework and eMMC Studio commits.
2. Build and test the web application with Node.js 22, then place release files in the Armbian overlay.
3. Check shell scripts and validate the first-boot setup-code lifecycle in a temporary Debian container.
4. Compile complete firmware with the Armbian build framework and Docker.
5. Mount the result read-only and check preinstalled files, enabled services, absence of shared credentials, and the U-Boot initramfs header.
6. Compress to `.img.xz`, attach SHA-256 checksums, source versions, and check reports, and publish a release only after success. Failed builds do not publish images; build logs are retained as Actions artifacts.

Build time depends on source downloads, upstream caches, and compilation load, with a 350-minute task limit. Pull requests run script checks only, without builds carrying publishing permissions. Release tags include the date and run number, and historical images are retained.

`sources.json` pins framework and application commits. Debian repositories, Armbian caches, and kernel sources referenced by the framework may still change, so byte-for-byte reproducibility is not claimed. Source commits are recorded in the release's `build-info.json` and the image's `/etc/emmc-studio-build.json`.

## Local builds

Requires Linux, working Docker, at least 8 GiB of RAM, and roughly 50 GiB of free space. See [Armbian build requirements](https://docs.armbian.com/build-framework/getting-started/). More disk space is recommended. On Windows, use a WSL2 Linux environment and avoid spaces in the build path.

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

Local output is `build/output/images/*.img`; compress it with `xz -T2 -6` if desired. `prepare.py` requires a clean overlay; use a new repository working directory for repeated builds. Preinstallation uses the [Armbian customize-image/overlay mechanism](https://docs.armbian.com/build-framework/user-configurations/) without modifying the official framework.

## Services and troubleshooting

```sh
systemctl status emmc-studio-firstboot emmc-worker emmc-web
sudo journalctl -u emmc-studio-firstboot -u emmc-worker -u emmc-web -b
hostname -I
curl http://127.0.0.1/api/v1/auth/status
cat /etc/emmc-studio-build.json
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,RO
```

The web interface runs as unprivileged `emmc-web`, with permission only to bind port 80. A root worker performs restricted disk operations through a Unix socket. Both application services restart on failure and start automatically at boot.

If the browser cannot connect, check the DHCP address, port 80, and the three services first. If eMMC is not recognized, check `lsblk`, MMC kernel logs, and physical connections rather than forcing writes based on a device number. The system SD card is identified and protected automatically; BOOT software read-only protection is restored after writes finish.

## Updating and uninstalling eMMC Studio

Update the web application separately while preserving the administrator and state:

```sh
curl -fL https://raw.githubusercontent.com/JasonYANG170/eMMC-Studio/main/install.sh -o /tmp/emmc-studio-install.sh
sudo sh /tmp/emmc-studio-install.sh
```

Uninstall the web application:

```sh
sudo systemctl disable --now emmc-studio-firstboot.service
sudo rm -f /etc/systemd/system/emmc-web.service.d/firstboot.conf
sudo sh /opt/emmc-studio/deploy/uninstall.sh
sudo systemctl daemon-reload
```

Uninstallation preserves administrator settings, backups, and task data by default. Reflashing the firmware system is a separate operation that erases the flashing target.

## Validation coverage

CI verifies builds, preinstalled files, the first-boot credential lifecycle, enabled services, and image boot-file formats. CI does not include a physical NanoPi R28S, so it cannot replace serial boot, network, eMMC/BOOT read, or physical USB testing. Published reports describe the checks actually performed; successful compilation is not treated as hardware acceptance.

Armbian lists this board as Community supported. Refer to the respective repositories for source and licensing requirements for the upstream kernel, U-Boot, firmware, and eMMC Studio. This repository does not change their licenses.
