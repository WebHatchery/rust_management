#!/usr/bin/env python3
"""Extract inline cfg(test) modules from Rust implementation files.

The replacement keeps the original attributes/declaration and changes the
module body to a semicolon. The body is written to Rust's corresponding child
module path, preserving `super` access without turning unit tests into an
integration crate.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import sys


CFG_TEST = re.compile(r"#\s*\[\s*cfg\s*\(\s*test\s*\)\s*\]")
MODULE = re.compile(
    r"(?:(?:pub(?:\s*\([^)]*\))?)\s+)?(?:unsafe\s+)?mod\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{"
)
IGNORED_DIRS = {".git", "target", "Release", "publish-logs"}


@dataclass(frozen=True)
class Extraction:
    start: int
    opening_brace: int
    end: int
    module_name: str


def skip_rust_token(source: str, index: int) -> int | None:
    """Return the position after a string/comment token starting at index."""
    if source.startswith("//", index):
        newline = source.find("\n", index + 2)
        return len(source) if newline < 0 else newline + 1
    if source.startswith("/*", index):
        depth = 1
        cursor = index + 2
        while cursor < len(source) and depth:
            if source.startswith("/*", cursor):
                depth += 1
                cursor += 2
            elif source.startswith("*/", cursor):
                depth -= 1
                cursor += 2
            else:
                cursor += 1
        return cursor

    raw = re.match(r'r(#+)?"', source[index:])
    if raw:
        hashes = raw.group(1) or ""
        closing = '"' + hashes
        end = source.find(closing, index + raw.end())
        return len(source) if end < 0 else end + len(closing)

    byte_raw = re.match(r'br(#+)?"', source[index:])
    if byte_raw:
        hashes = byte_raw.group(1) or ""
        closing = '"' + hashes
        end = source.find(closing, index + byte_raw.end())
        return len(source) if end < 0 else end + len(closing)

    prefix = 2 if source.startswith('b"', index) else 1
    if source.startswith('"', index) or source.startswith('b"', index):
        cursor = index + prefix
        while cursor < len(source):
            if source[cursor] == "\\":
                cursor += 2
            elif source[cursor] == '"':
                return cursor + 1
            else:
                cursor += 1
        return len(source)

    char_literal = re.match(r"(?:b)?'(?:\\.|[^'\\\n])'", source[index:])
    if char_literal:
        return index + char_literal.end()
    if source[index] == "'" and not re.match(r"'[A-Za-z_][A-Za-z0-9_]*", source[index:]):
        cursor = index + 1
        while cursor < len(source):
            if source[cursor] == "\\":
                cursor += 2
            elif source[cursor] == "'":
                return cursor + 1
            else:
                cursor += 1
        return len(source)
    return None


def matching_brace(source: str, opening: int) -> int:
    depth = 1
    cursor = opening + 1
    while cursor < len(source):
        skipped = skip_rust_token(source, cursor)
        if skipped is not None:
            cursor = skipped
            continue
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return cursor
        cursor += 1
    raise ValueError(f"unclosed module brace at byte {opening}")


def find_extractions(source: str) -> list[Extraction]:
    extractions: list[Extraction] = []
    cursor = 0
    while match := CFG_TEST.search(source, cursor):
        declaration_start = match.start()
        scan = match.end()
        module_match = None
        while scan < len(source):
            skipped = skip_rust_token(source, scan)
            if skipped is not None:
                scan = skipped
                continue
            if source[scan].isspace():
                scan += 1
                continue
            if source[scan] == "#":
                attr_end = source.find("]", scan + 1)
                if attr_end < 0:
                    break
                scan = attr_end + 1
                continue
            module_match = MODULE.match(source, scan)
            break
        if module_match is None:
            cursor = match.end()
            continue
        opening = module_match.end() - 1
        closing = matching_brace(source, opening)
        extractions.append(
            Extraction(declaration_start, opening, closing + 1, module_match.group(1))
        )
        cursor = closing + 1
    return extractions


def is_test_source(path: Path) -> bool:
    stem = path.stem.lower()
    return stem in {"test", "tests"} or stem.endswith("_test") or stem.endswith("_tests") or any(
        part.lower() in {"test", "tests"} for part in path.parts
    )


def child_path(parent: Path, module_name: str) -> Path:
    if parent.name in {"main.rs", "lib.rs", "mod.rs"}:
        module_dir = parent.parent
    else:
        module_dir = parent.parent / parent.stem
    return module_dir / f"{module_name}.rs"


def dedent_body(body: str) -> str:
    body = body.removeprefix("\r\n").removeprefix("\n")
    body = body.removesuffix("\r\n").removesuffix("\n")
    lines = body.splitlines()
    nonblank = [line for line in lines if line.strip()]
    if nonblank:
        indent = min(len(line) - len(line.lstrip()) for line in nonblank)
        lines = [line[indent:] if line.strip() else "" for line in lines]
    return "\n".join(lines).rstrip() + "\n"


def rust_files(root: Path, include_test_sources: bool):
    if root.is_file():
        if root.suffix == ".rs" and (include_test_sources or not is_test_source(root)):
            yield root
        return
    for path in root.rglob("*.rs"):
        if not any(part in IGNORED_DIRS for part in path.parts) and (
            include_test_sources or not is_test_source(path)
        ):
            yield path


def process(root: Path, write: bool, include_test_sources: bool) -> tuple[int, int]:
    changed_files = 0
    extracted_modules = 0
    for path in rust_files(root, include_test_sources):
        source = path.read_text(encoding="utf-8")
        try:
            extractions = find_extractions(source)
        except ValueError as error:
            raise ValueError(f"{path}: {error}") from error
        if not extractions:
            continue

        targets: list[tuple[Extraction, Path, str]] = []
        for extraction in extractions:
            target = child_path(path, extraction.module_name)
            if target.exists():
                raise FileExistsError(f"refusing to overwrite existing child module: {target}")
            body = dedent_body(source[extraction.opening_brace + 1 : extraction.end - 1])
            targets.append((extraction, target, body))

        relative = path.name if root.is_file() else path.relative_to(root)
        print(f"{relative}: {len(targets)} module(s)")
        if write:
            updated = source
            for extraction, _, _ in reversed(targets):
                declaration = updated[extraction.start : extraction.opening_brace].rstrip()
                updated = updated[: extraction.start] + declaration + ";" + updated[extraction.end :]
            path.write_text(updated, encoding="utf-8", newline="\n")
            for _, target, body in targets:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(body, encoding="utf-8", newline="\n")
        changed_files += 1
        extracted_modules += len(targets)
    return changed_files, extracted_modules


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", nargs="?", default=".")
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--include-test-sources", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    changed, extracted = process(root, args.write, args.include_test_sources)
    action = "Extracted" if args.write else "Would extract"
    print(f"{action} {extracted} module(s) from {changed} implementation file(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
