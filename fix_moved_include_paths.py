#!/usr/bin/env python3
"""Repair relative include_str/include_bytes paths after module extraction."""

from __future__ import annotations

import argparse
from pathlib import Path
import re


INCLUDE = re.compile(r'(?P<macro>include_(?:str|bytes)!)\(\s*"(?P<path>[^"]+)"\s*\)')
IGNORED_DIRS = {".git", "target", "Release", "publish-logs"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    changes = 0
    for source_path in root.rglob("*.rs"):
        if any(part in IGNORED_DIRS for part in source_path.parts):
            continue
        source = source_path.read_text(encoding="utf-8")

        def replacement(match: re.Match[str]) -> str:
            nonlocal changes
            literal = match.group("path")
            if Path(literal).is_absolute() or (source_path.parent / literal).is_file():
                return match.group(0)
            for depth in range(1, 7):
                candidate_literal = "../" * depth + literal
                if (source_path.parent / candidate_literal).is_file():
                    changes += 1
                    return f'{match.group("macro")}("{candidate_literal}")'
            return match.group(0)

        updated = INCLUDE.sub(replacement, source)
        if updated != source:
            print(source_path.relative_to(root))
            if args.write:
                source_path.write_text(updated, encoding="utf-8", newline="\n")
    action = "Repaired" if args.write else "Would repair"
    print(f"{action} {changes} moved include path(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
