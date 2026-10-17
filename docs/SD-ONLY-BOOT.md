# SD-only boot / 仅从 TF 卡启动

固件对 SPL 和 U-Boot 的自动启动实施 TF 卡限制，eMMC 继续作为 Linux 下的读卡目标。

此仓库使用 Armbian 的 `hinlink_rk3528_defconfig` 和 Radxa U-Boot。
友善 SDK 的 `nanopi_zero2` 补丁不能直接用于这条构建链，补丁已移植到实际使用的源码。
`sources.json` 和构建钩子固定 Radxa 源码提交。

补丁位于 `userpatches/u-boot/legacy/u-boot-radxa-rk35xx-v2024.10/board_nanopi-r28s/`。
Armbian 在 U-Boot 配置前应用补丁，构建钩子启用 `CONFIG_EMMC_STUDIO_SD_ONLY`。
补丁和钩子都进入 Armbian 的 U-Boot 缓存哈希，旧版无补丁的缓存不能复用。

- SPL 只加载 SD 控制器上的下一阶段。
- U-Boot 忽略指向 eMMC 的加载器启动提示，SD 不可用时停止。
- 自动启动命令只扫描 `mmc1`，不回退到 eMMC、USB 或网络。
- Linux 设备树和 eMMC 驱动保持启用，用户区、BOOT0/BOOT1 的读写不受此补丁影响。
- U-Boot 中的 MMC 索引与 Linux `/dev/mmcblkN` 编号不同。

CI 检查编译后的 U-Boot、SPL 策略标记和最终镜像内的 U-Boot 配置。
这些检查不代替真机串口及冷启动验收。

**范围限制：**补丁不能改变 RK3528 固化的 BootROM。
未插 TF 卡或 TF 加载器无效时，BootROM 仍可能执行 eMMC 上的另一份加载器。
若要求任何情况下都不运行 eMMC 上的代码，必须另行验证硬件启动配置或 eMMC 复位/供电控制。
本次不烧写 OTP/eFuse，也不擦除作为读卡目标的 eMMC 引导数据。

验收时使用测试 TF 卡和串口，确认输出 `eMMC Studio SPL: SD only` 及
`Bootdev(policy): mmc 1 (SD only)`，并检查 Linux 根文件系统来自 TF 卡。
克隆的 UUID/PARTUUID 可能重复，不能只凭内核从 SD 加载就认定根文件系统也来自 SD。

## English

The board patch restricts the compiled SPL and automatic U-Boot boot to SD.
Linux keeps the eMMC controller enabled for reader operations.
CI verifies the compiled policy markers and installed U-Boot configuration.
The Radxa source revision is pinned in `sources.json` and the build configuration.

This policy does not change the SoC BootROM or other loaders stored on eMMC.
Without a valid SD loader, BootROM may still boot eMMC.
Hardware-level exclusion requires separate board validation.
Confirm the serial markers and the actual Linux root device during hardware acceptance.
