#!/usr/bin/env python3
"""
Find Rust source files over a minimum line threshold, grouped by project.

Usage:
  python find_large_rs_files.py [root_dir] [--min-lines 500]

By default, root_dir is the current directory and min_lines is 500.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Tuple


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "root_dir",
        nargs="?",
        default=".",
        help="Root directory containing one or more Rust projects",
    )
    parser.add_argument(
        "--min-lines",
        type=int,
        default=500,
        help="Minimum number of lines to report (default: 500)",
    )
    return parser.parse_args()


def project_of(path: Path, root: Path) -> str:
    """
    Group files by project root, where a project is identified by the nearest parent
    directory that contains Cargo.toml.
    """
    current = path.parent
    while current.exists():
        if (current / "Cargo.toml").exists():
            return str(current.relative_to(root))
        if current == current.parent:
            break
        current = current.parent
    return "Unknown Project"


def find_large_files(root: Path, min_lines: int) -> Dict[str, List[Tuple[Path, int]]]:
    grouped: Dict[str, List[Tuple[Path, int]]] = defaultdict(list)

    for rs_file in root.rglob("*.rs"):
        if not rs_file.is_file():
            continue
        try:
            line_count = len(rs_file.read_text(encoding="utf-8", errors="ignore").splitlines())
        except OSError:
            continue

        if line_count > min_lines:
            grouped[project_of(rs_file, root)].append((rs_file, line_count))

    for files in grouped.values():
        files.sort(key=lambda x: x[1], reverse=True)

    return grouped


def main() -> int:
    args = parse_args()
    root = Path(args.root_dir).resolve()

    if not root.exists():
        raise SystemExit(f"Root directory does not exist: {root}")

    grouped = find_large_files(root, args.min_lines)
    if not grouped:
        print(f"No .rs files with more than {args.min_lines} lines found in {root}")
        return 0

    for project_name in sorted(grouped.keys()):
        files = grouped[project_name]
        if not files:
            continue
        print(f"\n[{project_name}]")
        for file_path, line_count in files:
            rel_path = file_path.relative_to(root)
            print(f"{line_count:>6}  {rel_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
