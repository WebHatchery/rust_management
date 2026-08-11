#!/usr/bin/env python3
"""Add explicit child paths for tests extracted from #[path]-loaded modules."""

from __future__ import annotations

import argparse
from pathlib import Path
import re


PATH_MODULE = re.compile(
    r'#\s*\[\s*path\s*=\s*"([^"]+)"\s*\]\s*'
    r'(?:pub(?:\s*\([^)]*\))?\s+)?mod\s+[A-Za-z_][A-Za-z0-9_]*\s*;'
)
TEST_MODULE = re.compile(
    r'(?P<cfg>#\s*\[\s*cfg\s*\(\s*test\s*\)\s*\]\s*)'
    r'(?P<declaration>(?:(?:pub(?:\s*\([^)]*\))?)\s+)?mod\s+'
    r'(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*;)'
)
IGNORED_DIRS = {".git", "target", "Release", "publish-logs"}


def rust_files(root: Path):
    for path in root.rglob("*.rs"):
        if not any(part in IGNORED_DIRS for part in path.parts):
            yield path


def path_loaded_files(root: Path) -> set[Path]:
    loaded: set[Path] = set()
    for declarer in rust_files(root):
        source = declarer.read_text(encoding="utf-8")
        for match in PATH_MODULE.finditer(source):
            target = (declarer.parent / match.group(1)).resolve()
            if target.is_file():
                loaded.add(target)
    return loaded


def fix_file(path: Path, write: bool) -> int:
    source = path.read_text(encoding="utf-8")
    changes = 0

    def replacement(match: re.Match[str]) -> str:
        nonlocal changes
        module_name = match.group("name")
        child = path.parent / path.stem / f"{module_name}.rs"
        if not child.is_file():
            return match.group(0)
        changes += 1
        child_path = f'{path.stem}/{module_name}.rs'
        return f'{match.group("cfg")}#[path = "{child_path}"]\n{match.group("declaration")}'

    updated = TEST_MODULE.sub(replacement, source)
    if changes:
        print(f"{path}: {changes} explicit child path(s)")
        if write:
            path.write_text(updated, encoding="utf-8", newline="\n")
    return changes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    changed = sum(fix_file(path, args.write) for path in sorted(path_loaded_files(root)))
    action = "Added" if args.write else "Would add"
    print(f"{action} {changed} explicit child module path(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
