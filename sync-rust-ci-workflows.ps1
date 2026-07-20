# Synchronize the shared GitHub Actions Rust CI workflow across top-level Rust game projects.

param(
    [string[]]$Project,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Get-RustCiWorkflow {
    @'
name: Rust Game CI

on:
  workflow_dispatch:
  push:
    branches: [main, master]
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  CARGO_TERM_COLOR: always

jobs:
  checks-and-webgl:
    name: Check, test, and build WebGL
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: game

    steps:
      - name: Checkout game
        uses: actions/checkout@v4
        with:
          path: game

      - name: Checkout macroquad-toolkit
        uses: actions/checkout@v4
        with:
          repository: Kalaith/macroquad-toolkit
          path: macroquad-toolkit

      - name: Install Linux build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y --no-install-recommends \
            pkg-config \
            libasound2-dev \
            libudev-dev \
            libx11-dev \
            libxi-dev \
            libgl1-mesa-dev

      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          components: rustfmt, clippy
          targets: wasm32-unknown-unknown

      - name: Show Rust version
        run: |
          rustc --version
          cargo --version
          cargo clippy --version

      - name: Cache Cargo
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            game/target
          key: ${{ runner.os }}-rust-game-cargo-${{ hashFiles('game/Cargo.lock', 'game/Cargo.toml', 'macroquad-toolkit/Cargo.toml') }}
          restore-keys: |
            ${{ runner.os }}-rust-game-cargo-

      - name: Verify project files
        run: |
          test -f Cargo.toml
          test -f index.html
          test -d assets
          test -d ../macroquad-toolkit
          if [ ! -s catalog_thumbnail.png ]; then
            echo "::warning::catalog_thumbnail.png is missing or empty"
          fi

      - name: Check formatting
        run: cargo fmt --manifest-path Cargo.toml -- --check

      - name: Run Clippy
        run: cargo clippy --manifest-path Cargo.toml --all-targets --all-features -- -D warnings

      - name: Run tests
        run: cargo test --manifest-path Cargo.toml --all-features

      - name: Build WebGL release
        run: cargo build --manifest-path Cargo.toml --release --target wasm32-unknown-unknown
        env:
          RUSTFLAGS: "-C link-arg=--allow-undefined"

      - name: Verify WebGL output
        run: |
          wasm_name="$(cargo metadata --manifest-path Cargo.toml --no-deps --format-version 1 | python3 -c 'import json, sys; from pathlib import Path; metadata = json.load(sys.stdin); manifest = Path("Cargo.toml").resolve(); package = next((package for package in metadata["packages"] if Path(package["manifest_path"]).resolve() == manifest), metadata["packages"][0]); bins = [target["name"] for target in package["targets"] if "bin" in target["kind"]]; name = bins[0] if bins else package["name"]; print(name.replace("-", "_") + ".wasm")')"
          test -s "target/wasm32-unknown-unknown/release/${wasm_name}"

  windows-build:
    name: Build Windows release
    runs-on: windows-latest
    defaults:
      run:
        working-directory: game

    steps:
      - name: Checkout game
        uses: actions/checkout@v4
        with:
          path: game

      - name: Checkout macroquad-toolkit
        uses: actions/checkout@v4
        with:
          repository: Kalaith/macroquad-toolkit
          path: macroquad-toolkit

      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable

      - name: Show Rust version
        run: |
          rustc --version
          cargo --version

      - name: Cache Cargo
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            game/target
          key: ${{ runner.os }}-rust-game-cargo-${{ hashFiles('game/Cargo.lock', 'game/Cargo.toml', 'macroquad-toolkit/Cargo.toml') }}
          restore-keys: |
            ${{ runner.os }}-rust-game-cargo-

      - name: Build Windows release
        run: cargo build --manifest-path Cargo.toml --release

      - name: Verify Windows output
        run: |
          $metadata = cargo metadata --manifest-path Cargo.toml --no-deps --format-version 1 | ConvertFrom-Json
          $manifestPath = (Resolve-Path "Cargo.toml").Path
          $package = @($metadata.packages | Where-Object { (Resolve-Path $_.manifest_path).Path -eq $manifestPath } | Select-Object -First 1)
          if (-not $package) {
            $package = $metadata.packages[0]
          }
          $bin = @($package.targets | Where-Object { $_.kind -contains "bin" } | Select-Object -First 1).name
          if (-not $bin) {
            $bin = $package.name
          }
          $exePath = Join-Path "target\release" "$bin.exe"
          if (-not (Test-Path $exePath -PathType Leaf)) {
            throw "Missing $exePath"
          }
'@
}

function Get-RustGameProjects {
    # This script lives in rust_management/; the game projects are in its parent.
    $root = Split-Path -Parent $PSScriptRoot
    $excluded = @(
        ".vscode",
        "archive",
        "assets",
        "docs",
        "macroquad-toolkit",
        "publish-logs",
        "Release",
        "target",
        "title_screeshots"
    )

    Get-ChildItem -LiteralPath $root -Directory |
        Where-Object {
            $_.Name -notin $excluded -and
            (Test-Path (Join-Path $_.FullName "Cargo.toml") -PathType Leaf) -and
            (Test-Path (Join-Path $_.FullName "publish.ps1") -PathType Leaf)
        } |
        Sort-Object Name
}

$workflow = Get-RustCiWorkflow
$projects = Get-RustGameProjects

if ($Project.Count -gt 0) {
    $projectNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $Project) {
        [void]$projectNames.Add($name)
    }
    $projects = $projects | Where-Object { $projectNames.Contains($_.Name) }
}

if (-not $projects) {
    Write-Warning "No matching Rust game projects found."
    exit 0
}

foreach ($projectDir in $projects) {
    $workflowDir = Join-Path $projectDir.FullName ".github\workflows"
    $workflowPath = Join-Path $workflowDir "rust-ci.yml"

    if ($WhatIf) {
        Write-Host "Would write $workflowPath"
        continue
    }

    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
    Set-Content -LiteralPath $workflowPath -Value $workflow -Encoding utf8
    Write-Host "Wrote $workflowPath"
}
