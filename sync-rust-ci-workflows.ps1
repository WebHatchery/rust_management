# Synchronize the shared GitHub Actions Rust CI workflow across top-level Rust game projects.

param(
    [string[]]$Project,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Games that need a sibling repository checked out beyond macroquad-toolkit.
#
# CI builds each game from a standalone checkout, so a path dependency on
# anything outside the game's own repo cannot resolve unless that repo is
# fetched alongside it. Declaring it here rather than hand-editing the game's
# workflow is what stops a re-sync from silently breaking that game's CI.
#
# Keyed by project directory name; each entry is the sibling path, the GitHub
# repository to fetch into it, and why the game needs it.
$ExtraCheckouts = @{
    "tb_realms" = @(
        @{
            Path       = "mytherra"
            Repository = "Kalaith/mytherra_rust"
            Reason     = "world source: path deps on mytherra-core and mytherra-protocol (GDD 5.1)"
        }
    )
}

# Games that are multi-crate Cargo workspaces rather than a single package.
#
# The default fmt/clippy/test steps check only the root package, which silently
# skips every sibling crate — a server, a protocol crate, a persistence layer —
# so a workspace game needs its own scope. Build steps are deliberately NOT
# scoped: a native-only crate (a tokio server, say) cannot be built for wasm,
# so only the checks widen.
#
# Keyed by project directory name. `FmtArgs` are package flags for `cargo fmt`,
# which has no `--workspace`; `CheckArgs` widen clippy and test.
$WorkspaceScopes = @{
    "mytherra" = @{
        FmtArgs   = "-p mytherra -p mytherra-core -p mytherra-protocol -p mytherra-server"
        CheckArgs = "--workspace"
        Reason    = "the authority server, protocol and persistence crates must be checked too"
    }
}

# The scope flags for a project, as a leading-space-prefixed string to splice
# into a cargo invocation, or empty for a plain single-package game.
function Get-ScopeArg {
    param([string]$ProjectName, [string]$Key)

    $scope = $WorkspaceScopes[$ProjectName]
    if (-not $scope -or -not $scope[$Key]) { return "" }
    " $($scope[$Key])"
}

# Render the extra `actions/checkout` steps for a project, indented to sit
# beside the macroquad-toolkit checkout. Empty string when a project needs none.
function Get-ExtraCheckoutSteps {
    param([string]$ProjectName)

    $extras = $ExtraCheckouts[$ProjectName]
    if (-not $extras) { return "" }

    $blocks = foreach ($extra in $extras) {
        @"

      # $($extra.Reason)
      - name: Checkout $($extra.Path)
        uses: actions/checkout@v4
        with:
          repository: $($extra.Repository)
          path: $($extra.Path)
"@
    }
    ($blocks -join "")
}

# Render the matching `test -d` assertions, so a checkout that silently produced
# no directory is caught by the verify step rather than surfacing later as a
# confusing unresolved-dependency error.
function Get-ExtraVerifyLines {
    param([string]$ProjectName)

    $extras = $ExtraCheckouts[$ProjectName]
    if (-not $extras) { return "" }

    $lines = foreach ($extra in $extras) {
        "`n          test -d ../$($extra.Path)"
    }
    ($lines -join "")
}

function Get-RustCiWorkflow {
    param([string]$ProjectName)

    $template = @'
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
{{EXTRA_CHECKOUTS}}

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
          test -d assets
          test -d ../macroquad-toolkit{{EXTRA_VERIFY}}
          if [ ! -s catalog_thumbnail.png ]; then
            echo "::warning::catalog_thumbnail.png is missing or empty"
          fi

      - name: Check formatting
        run: cargo fmt --manifest-path Cargo.toml{{FMT_ARGS}} -- --check

      - name: Run Clippy
        run: cargo clippy --manifest-path Cargo.toml{{CHECK_ARGS}} --all-targets --all-features -- -D warnings

      - name: Run tests
        run: cargo test --manifest-path Cargo.toml{{CHECK_ARGS}} --all-features

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
{{EXTRA_CHECKOUTS}}

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

    # Substitute after the literal here-string, so nothing in the YAML above is
    # expanded by PowerShell. A project with no extras gets the placeholder
    # lines removed entirely rather than left as blanks.
    $checkouts = Get-ExtraCheckoutSteps -ProjectName $ProjectName
    $verify = Get-ExtraVerifyLines -ProjectName $ProjectName

    if ($checkouts) {
        $template = $template.Replace("{{EXTRA_CHECKOUTS}}", $checkouts)
    }
    else {
        $template = $template -replace "(\r?\n)\{\{EXTRA_CHECKOUTS\}\}", ""
    }
    $template = $template.Replace("{{EXTRA_VERIFY}}", $verify)
    $template = $template.Replace("{{FMT_ARGS}}", (Get-ScopeArg -ProjectName $ProjectName -Key "FmtArgs"))
    $template = $template.Replace("{{CHECK_ARGS}}", (Get-ScopeArg -ProjectName $ProjectName -Key "CheckArgs"))

    # Match only our own placeholders — GitHub's `${{ ... }}` expressions are
    # legitimately full of double braces.
    if ($template -match "\{\{(EXTRA_|FMT_ARGS|CHECK_ARGS)") {
        throw "Unsubstituted placeholder left in the workflow for $ProjectName"
    }

    $template
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
    $workflow = Get-RustCiWorkflow -ProjectName $projectDir.Name

    $notes = @()
    if ($ExtraCheckouts[$projectDir.Name]) {
        $notes += "+ $((($ExtraCheckouts[$projectDir.Name] | ForEach-Object { $_.Path }) -join ', '))"
    }
    if ($WorkspaceScopes[$projectDir.Name]) {
        $notes += "workspace-scoped checks"
    }
    $note = if ($notes) { " ($($notes -join '; '))" } else { "" }

    if ($WhatIf) {
        Write-Host "Would write $workflowPath$note"
        continue
    }

    New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
    Set-Content -LiteralPath $workflowPath -Value $workflow -Encoding utf8
    Write-Host "Wrote $workflowPath$note"
}
