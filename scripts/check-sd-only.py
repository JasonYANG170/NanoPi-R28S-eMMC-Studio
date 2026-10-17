"""Check the board patch against the U-Boot revision used by CI."""

import argparse
import json
from pathlib import Path
import subprocess
import tempfile


def check_postprocess_hook(root):
    """Match the explicit FIT build targets: no u-boot.bin is generated."""
    with tempfile.TemporaryDirectory(prefix="sd-only-fit-output-") as directory:
        target = Path(directory)
        payloads = {
            ".config": b"CONFIG_EMMC_STUDIO_SD_ONLY=y\n",
            "u-boot": b"\x7fELF\x00Bootdev(policy): mmc 1 (SD only)\x00",
            "spl/u-boot-spl.bin": b"\x00eMMC Studio SPL: SD only\x00",
        }
        for name, data in payloads.items():
            path = target / name
            path.parent.mkdir(exist_ok=True, parents=True)
            path.write_bytes(data)

        def run():
            return subprocess.run(
                [
                    "bash",
                    "-euc",
                    'source "$1"; exit_with_error() { echo "$*" >&2; exit 1; }; '
                    "BOOT_SCENARIO=spl-blobs; post_uboot_custom_postprocess__emmc_studio_sd_only",
                    "check-postprocess",
                    str(root / "userpatches/config-emmc-studio.conf"),
                ],
                cwd=target,
                capture_output=True,
                text=True,
            )

        assert not (target / "u-boot.bin").exists()
        result = run()
        assert result.returncode == 0, result.stderr
        for name, error in (
            (".config", "SD-only config was not enabled"),
            ("u-boot", "U-Boot policy marker is missing"),
            ("spl/u-boot-spl.bin", "SPL policy marker is missing"),
        ):
            (target / name).write_bytes(b"missing-policy")
            result = run()
            assert result.returncode != 0 and error in result.stderr, result
            (target / name).write_bytes(payloads[name])
    print(
        "PASS: FIT output without u-boot.bin is accepted; missing config or policy markers are rejected."
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--uboot", type=Path, required=True)
    parser.add_argument("--armbian", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    check_postprocess_hook(root)
    info = json.loads((root / "sources.json").read_text())
    revision = subprocess.check_output(
        ["git", "-C", str(args.uboot), "rev-parse", "HEAD"], text=True
    ).strip()
    assert revision == info["uboot"]["commit"], "Unexpected U-Boot revision"
    config = (root / "userpatches/config-emmc-studio.conf").read_text()
    assert "commit:" + revision in config, "Source pin differs from build metadata"
    patch = (
        root
        / "userpatches/u-boot/legacy/u-boot-radxa-rk35xx-v2024.10/board_nanopi-r28s/9999-emmc-studio-sd-only.patch"
    )
    files = (
        "arch/arm/mach-rockchip/Kconfig",
        "arch/arm/mach-rockchip/boot_rkimg.c",
        "arch/arm/mach-rockchip/spl-boot-order.c",
        "include/configs/rockchip-common.h",
    )
    with tempfile.TemporaryDirectory(prefix="sd-only-policy-") as directory:
        target = Path(directory)
        for name in files:
            path = target / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(
                subprocess.check_output(
                    ["git", "-C", str(args.uboot), "show", "HEAD:" + name]
                )
            )
        subprocess.run(["git", "init", "-q", str(target)], check=True)
        subprocess.run(
            ["git", "-C", str(target), "apply", "--check", str(patch)], check=True
        )
        subprocess.run(["git", "-C", str(target), "apply", str(patch)], check=True)
        subprocess.run(
            ["git", "-C", str(target), "apply", "--reverse", "--check", str(patch)],
            check=True,
        )
        defconfig = target / "configs/hinlink_rk3528_defconfig"
        defconfig.parent.mkdir()
        overlay = (
            args.armbian
            / "patch/u-boot/legacy/u-boot-radxa-rk35xx/defconfig/hinlink_rk3528_defconfig"
        )
        defconfig.write_bytes(overlay.read_bytes())
        subprocess.run(
            [
                "bash",
                "-euc",
                'source "$1"; exit_with_error() { echo "$*" >&2; exit 1; }; '
                "BOOTCONFIG=hinlink_rk3528_defconfig; BOOTSOURCE=https://github.com/radxa/u-boot.git; "
                "post_family_config__emmc_studio_sd_only; "
                "pre_config_uboot_target__emmc_studio_sd_only; "
                "pre_config_uboot_target__emmc_studio_sd_only; "
                'test "$(grep -c "^CONFIG_EMMC_STUDIO_SD_ONLY=y$" "configs/$BOOTCONFIG")" = 1',
                "check-sd-only",
                str(root / "userpatches/config-emmc-studio.conf"),
            ],
            cwd=target,
            check=True,
        )
    print(
        "PASS: pinned U-Boot patch applies and reverses; board hook enables SD-only policy idempotently."
    )


if __name__ == "__main__":
    main()
