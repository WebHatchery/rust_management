#!/usr/bin/env python3
"""Split top-level Rust test functions into bounded child modules."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re

from extract_inline_tests import matching_brace, skip_rust_token


TEST_ATTRIBUTE = re.compile(r"(?m)^#\[test(?:\([^\]]*\))?\]\s*$")


@dataclass(frozen=True)
class TestItem:
    start: int
    end: int
    text: str

    @property
    def lines(self) -> int:
        return self.text.count("\n") + 1


def depth_at(source: str, position: int) -> int:
    depth = 0
    cursor = 0
    while cursor < position:
        skipped = skip_rust_token(source, cursor)
        if skipped is not None:
            cursor = skipped
            continue
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
        cursor += 1
    return depth


def opening_function_brace(source: str, start: int) -> int:
    cursor = start
    while cursor < len(source):
        skipped = skip_rust_token(source, cursor)
        if skipped is not None:
            cursor = skipped
            continue
        if source[cursor] == "{":
            return cursor
        cursor += 1
    raise ValueError(f"test at byte {start} has no function body")


def test_items(source: str) -> list[TestItem]:
    items: list[TestItem] = []
    for match in TEST_ATTRIBUTE.finditer(source):
        if depth_at(source, match.start()) != 0:
            continue
        opening = opening_function_brace(source, match.end())
        closing = matching_brace(source, opening)
        end = closing + 1
        while end < len(source) and source[end] in "\r\n":
            end += 1
        items.append(TestItem(match.start(), end, source[match.start() : end].rstrip() + "\n"))
    return items


def child_directory(path: Path) -> Path:
    if path.name == "mod.rs":
        return path.parent
    return path.parent / path.stem


def groups(items: list[TestItem], max_lines: int) -> list[list[TestItem]]:
    result: list[list[TestItem]] = []
    current: list[TestItem] = []
    current_lines = 1  # `use super::*;`
    for item in items:
        if current and current_lines + item.lines + 1 > max_lines:
            result.append(current)
            current = []
            current_lines = 1
        current.append(item)
        current_lines += item.lines + 1
    if current:
        result.append(current)
    return result


def split_file(path: Path, max_lines: int, write: bool) -> tuple[int, int]:
    source = path.read_text(encoding="utf-8")
    items = test_items(source)
    if not items:
        return 0, 0
    batches = groups(items, max_lines)
    directory = child_directory(path)
    targets = [directory / f"test_part_{index}.rs" for index in range(1, len(batches) + 1)]
    existing = [target for target in targets if target.exists()]
    if existing:
        raise FileExistsError(f"refusing to overwrite: {existing}")

    updated = source
    for item in reversed(items):
        updated = updated[: item.start] + updated[item.end :]
    declarations = "\n".join(f"mod test_part_{index};" for index in range(1, len(batches) + 1))
    updated = updated.rstrip() + "\n\n" + declarations + "\n"

    projected = updated.count("\n")
    print(
        f"{path}: {len(items)} tests -> {len(batches)} child files; "
        f"parent {projected} lines"
    )
    if projected > 800:
        raise ValueError(f"split leaves oversized parent {path}: {projected} lines")
    if write:
        path.write_text(updated, encoding="utf-8", newline="\n")
        directory.mkdir(parents=True, exist_ok=True)
        for target, batch in zip(targets, batches):
            content = "use super::*;\n\n" + "\n".join(item.text.rstrip() for item in batch) + "\n"
            target.write_text(content, encoding="utf-8", newline="\n")
    return len(items), len(batches)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--max-lines", type=int, default=700)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    total_tests = 0
    total_children = 0
    for raw_path in args.paths:
        tests, children = split_file(Path(raw_path).resolve(), args.max_lines, args.write)
        total_tests += tests
        total_children += children
    action = "Split" if args.write else "Would split"
    print(f"{action} {total_tests} tests into {total_children} child files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
