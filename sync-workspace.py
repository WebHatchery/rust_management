"""Install/check the versioned workspace configuration and Macroquad policy.

Run with Python 3.11+. Lock updates remain Cargo's responsibility; --capture-lock
records the resolved root lock only after its Macroquad version passes policy.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import tomllib

MANAGEMENT = Path(__file__).resolve().parent
ROOT = MANAGEMENT.parent
CANONICAL = MANAGEMENT / "workspace"


def read_toml(path):
    return tomllib.loads(path.read_text(encoding="utf-8-sig"))


def manifests():
    # Registered members plus intentional standalone projects and the template.
    workspace = read_toml(CANONICAL / "Cargo.toml")["workspace"]
    paths = {ROOT / name / "Cargo.toml" for name in workspace["members"]}
    for name in ("mytherra", "tarrowyn", "rust_management/template", "rust_management/2dmmo", "rust_management/archive/romcon"):
        path = ROOT / name / "Cargo.toml"
        if path.exists():
            paths.add(path)
    return sorted(paths)


def assert_lock_version(path, version):
    versions = {p["version"] for p in read_toml(path)["package"] if p["name"] == "macroquad"}
    if versions != {version}:
        raise ValueError(f"{path}: expected Macroquad {version}, got {sorted(versions)}. Update with Cargo first.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check deployed files, direct pins and authoritative locks without changes")
    parser.add_argument("--pin", action="store_true", help="Apply the exact Macroquad version to registered game/toolkit manifests")
    parser.add_argument("--capture-lock", action="store_true", help="Record the actual root Cargo.lock after a deliberate dependency update")
    args = parser.parse_args()
    if args.check and (args.pin or args.capture_lock):
        parser.error("--check cannot be combined with mutation options")
    policy = json.loads((CANONICAL / "build-policy.json").read_text())
    version = policy["macroquad_version"]
    errors = []
    for path in manifests():
        data = read_toml(path)
        dep = data.get("dependencies", {}).get("macroquad")
        if dep is None:
            continue
        actual = dep if isinstance(dep, str) else dep.get("version")
        if actual == f"={version}":
            continue
        if args.pin:
            content = path.read_text(encoding="utf-8")
            content, count = re.subn(
                r'(?m)^(macroquad\s*=\s*(?:\{\s*version\s*=\s*)?)"[^"]+"',
                lambda m: f'{m[1]}"={version}"', content,
            )
            if count != 1:
                raise ValueError(f"Cannot safely update Macroquad dependency in {path}")
            path.write_text(content, encoding="utf-8", newline="\n")
            print(f"Pinned {path.relative_to(ROOT)}")
        else:
            errors.append(f"{path.relative_to(ROOT)}: Macroquad must be exactly ={version}")
    if args.capture_lock:
        assert_lock_version(ROOT / "Cargo.lock", version)
        shutil.copyfile(ROOT / "Cargo.lock", CANONICAL / "Cargo.lock")
        print("Recorded resolved root Cargo.lock")
    files = (("Cargo.toml", "Cargo.toml"), ("Cargo.lock", "Cargo.lock"), ("config.toml", ".cargo/config.toml"))
    for source, destination in files:
        src, dst = CANONICAL / source, ROOT / destination
        if args.check:
            # Git and Windows may use different line endings.
            if not dst.exists() or src.read_text() != dst.read_text():
                errors.append(f"Workspace configuration drift: {destination}")
        else:
            if destination == "Cargo.lock" and dst.exists() and src.read_text() != dst.read_text():
                raise ValueError("Root Cargo.lock has changed. Use --capture-lock to record it before installing configuration.")
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)
    if args.check:
        for path in (ROOT / "Cargo.lock", ROOT / "mytherra/Cargo.lock", ROOT / "tarrowyn/Cargo.lock"):
            try:
                assert_lock_version(path, version)
            except ValueError as error:
                errors.append(str(error))
    if errors:
        raise SystemExit("\n".join(errors))
    print("Workspace configuration and Macroquad policy checked." if args.check else "Workspace configuration installed.")


if __name__ == "__main__":
    main()
