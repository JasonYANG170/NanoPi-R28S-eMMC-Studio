"""Stage only distribution files; record the actual source revisions."""
import json
import shutil
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
studio = root / "studio"
build = root / "build"
sources = json.loads((root / "sources.json").read_text())


def revision(path):
    return subprocess.check_output(["git", "-C", str(path), "rev-parse", "HEAD"], text=True).strip()


assert revision(build) == sources["armbian"]["commit"]
assert revision(studio).startswith(sources["studio"]["commit"])
target = root / "userpatches/overlay/emmc-studio"
assert not target.exists(), "Overlay already exists; use a fresh checkout."
target.mkdir(parents=True)
for name in ("backend", "deploy"):
    (target / name).mkdir()
    for path in (studio / name).iterdir():
        if path.suffix in (".py", ".sh", ".service"):
            assert not path.is_symlink()
            shutil.copy2(path, target / name / path.name)
shutil.copytree(studio / "dist", target / "dist")
for name in ("README.md", "VERSION"):
    shutil.copy2(studio / name, target / name)
assert (target / "dist/index.html").is_file()
sources["armbian"]["commit"] = revision(build)
sources["studio"]["commit"] = revision(studio)
sources["studio"]["version"] = (studio / "VERSION").read_text().strip()
sources["firmware_commit"] = revision(root)
(root / "userpatches/overlay/build-info.json").write_text(json.dumps(sources, indent=2) + "\n")
shutil.copytree(root / "userpatches", build / "userpatches", dirs_exist_ok=True)
print(json.dumps(sources, indent=2))
