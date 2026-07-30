# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`RustGames` is a monorepo of ~20 independent Rust + `macroquad` games (WebGL + native Windows) published to the WebHatchery games catalog. The workspace root itself is **not** a git repository — each game subdirectory (`ai_defense/`, `apartment/`, `dungeon_manager/`, etc.) is its own independent git repo. A root `Cargo.toml` ties them together as a Cargo workspace purely for convenience (shared `target/`, one `cargo check` across everything); it does not imply shared versioning or releases.

## Directory layout

**This file lives in `rust_management/`, which is its own git repo and holds everything that is not a game:** the publish/build tooling, `docs/`, `template/`, `archive/`, `title_screeshots/`, and `web/` (the shared page shell plus `shared.css` and the bug-report widget).

The **workspace root** (`rust_management`'s parent) holds only the game repos, `macroquad-toolkit/`, `Cargo.toml`/`Cargo.lock`, and the build outputs `target/`, `Release/`, `publish-logs/`.

The `*.ps1` files at the workspace root are **pointers** that forward here — run any command from either location. They carry a real `param()` block on purpose: forwarding with `@args` corrupts switches (PowerShell splits `-Production:$false` into `-Production:` and `False`, and the target then binds a bare `-Production` as `$true`, silently deploying to production). If you add a parameter to a script here, mirror it in the root pointer.

Scripts here resolve two different roots: `$ManagementRoot` (`$PSScriptRoot`) for tooling and web assets, and `$WorkspaceRoot` (its parent) for games, `Release/` and `publish-logs/`. Use the right one.

Two non-game members matter most:
- **`macroquad-toolkit/`** — a shared crate (path dependency `{ path = "../macroquad-toolkit" }`) providing input, UI widgets, asset/texture management, camera, event bus, color palette, sprites, persistence, pathfinding, and the screenshot-capture harness used by every game.
- **`template/`** — a working starter game pre-wired to the toolkit; copy it as the starting point for a new game (see its README's "Rename For A New Game" steps).

`docs/` is the canonical source for four documents that are duplicated verbatim into every game project: `AGENTS.md`, `CODE_STANDARDS.md`, `MACROQUAD_TOOLKIT.md`, `GAME_DEVELOPMENT_GUIDE.md`. Never hand-edit a project-local copy's shared content — put project-specific guidance in that project's README or a `PROJECT_AGENTS.md` instead, and use the sync scripts below to manage the shared files.

## Commands

There's no top-level `cargo test`/`cargo build` workflow spanning "the product" — each game is built, tested, and shipped independently from its own directory.

**Per-game loop** (run from inside a game directory, e.g. `apartment/`):
```powershell
cargo build                          # native debug build
cargo run                            # run the game
cargo test                           # run tests; cargo test <name> for a single test
cargo fmt -- --check                 # formatting check (CI enforces this)
cargo clippy --all-targets --all-features -- -D warnings   # lint (CI treats warnings as errors)
cargo build --release --target wasm32-unknown-unknown      # WebGL/WASM build
```

**Publishing / validation** — every game has a `publish.ps1` that wraps the root `publish.ps1` (invoked with `-RustGamePublish -ProjectDir <path>`). Per `AGENTS.md`, this is the sanctioned end-to-end validation path after meaningful changes:
```powershell
.\publish.ps1                # from inside the game dir: build Windows + WebGL, deploy
.\publish.ps1 -WebGLOnly      # -WindowsOnly, -DeployOnly, -Production (-p), -FTP, -DryRun also available
```
For tight iteration, prefer `cargo clippy` + `cargo test` over a full publish — that's what each game's CI (`.github/workflows/rust-ci.yml`) actually runs. Only run `publish.ps1` in the specific project directory you changed; don't run workspace-wide publishing (below) without being asked, since it builds and can deploy every game.

**Workspace-wide scripts** (in `rust_management/`, also runnable from the workspace root via the pointers):
- `.\build_all_webgl.ps1` — runs every game's `publish.ps1`, collects WebGL + Windows artifacts into `Release/`, generates a catalog `index.html`.
- `.\publish-all.ps1` / `.\publish-all-ftp.ps1` — runs `publish.ps1` in every game subdirectory (excludes `template`, `target`, `assets`, `macroquad-toolkit`).
- `.\docs\check-project-docs.ps1` [-ProjectRoot <names>] — verifies each game's local copy of the four shared docs matches the canonical one in `docs/`; non-zero exit on drift.
- `.\docs\sync-project-docs.ps1` [-ProjectRoot <names>] [-IncludeWorkspaceRoot] — overwrites project-local copies from `docs/`.
- `.\sync-rust-ci-workflows.ps1` [-Project <names>] [-WhatIf] — syncs the shared `rust-ci.yml` GitHub Actions workflow across top-level projects. The workflow is a here-string inside the script, so **edit it there, never in a game's `.github/`** — a re-sync overwrites every project-local copy. A game needing a sibling repo beyond `macroquad-toolkit` (CI builds each game from a standalone checkout, so a path dependency outside its own repo cannot otherwise resolve) declares it in the script's `$ExtraCheckouts` map, which injects the checkout into both jobs plus a `test -d` assertion; `tb_realms` uses this for `mytherra`. The sync is idempotent.
- `python find_large_rs_files.py [root_dir] [--min-lines 500]` — audits `.rs` files approaching/over the size limit.
- `.\capture-title-screenshots.ps1 -Publish` — refreshes each game's title-screen capture into `catalog_thumbnail.png`.
- `..\macroquad-toolkit\scripts\capture_ui.ps1 -Scenes <scene1,scene2>` (run from inside a game dir) — builds the game and captures headless UI screenshots per scene for visual verification; derives package/exe/env-prefix from `cargo metadata`, so no arguments needed beyond `-Scenes` (pass `-Prefix` if the game's env-var prefix differs from its package name, e.g. `carriage_run` → `CARRIAGE`).

## Architecture

### Per-game structure (applies to essentially every project here)

Every game follows the same skeleton, described in full in `docs/GAME_DEVELOPMENT_GUIDE.md` and `docs/CODE_STANDARDS.md`:

- A single `#[macroquad::main]` loop in `main.rs` owning a `Game` struct, calling `update()` then `draw()` each frame.
- **State machine**: a `GameState` enum (e.g. `Menu(MenuState)`, `Gameplay(GameplayState)`) where only one state is active; each state's `update()` returns `Option<StateTransition>`, and `Game::transition()` applies it explicitly. No shared mutable globals, no magic callbacks.
- **Domain modules** by responsibility: `data/` (JSON-backed types, no knowledge of engine/UI), `engine/` or `simulation/` (stateless services — receive state, return results), `state/` (current + persistent state, save/load), `ui/` (rendering only).
- **UI is a pure view layer** — it reads state and returns `UiAction`/intent enums; it never mutates game state directly. A dispatcher (often `*_actions.rs`) interprets those intents. When adding an interaction, add a `UiAction` variant rather than reaching into state from a panel.
- **Data-driven design is a hard rule**: balance values, content, and text live as JSON under `assets/`, loaded via `serde` (often through `macroquad_toolkit::data_loader`). Prefer editing `assets/*.json` over hardcoding constants in Rust. Native builds may read `assets/` from disk with an embedded (`include_str!`) fallback for WASM — check a given project's `data.rs`/`config.rs` before assuming hot-reload works there.
- **Module filenames**: use `foo.rs` (for `mod foo;`) plus a `foo/` directory for children — **never** create new `mod.rs` files. When restructuring, migrate `foo/mod.rs` → `foo.rs`, don't leave both present (ambiguous module source).

### Hard constraints (from `AGENTS.md` / `docs/CODE_STANDARDS.md`)

- **800-line hard limit on every `.rs` file** (soft target 200–400, soft limit 600). Approaching the limit is a signal to extract a cohesive responsibility into a sibling module — never satisfy it by stripping whitespace, compressing formatting, or moving one small function. If a touched file is already over 800 lines, do the restructure as part of the current task.
- **Reach for `macroquad-toolkit` first.** Treat any missing runtime/rendering/input/asset/platform capability as a candidate toolkit upgrade before writing a project-local alternative. Only diverge when an existing project has an established alternative or the need is genuinely game-specific.
- No unused code: delete unused fields/functions outright rather than `_`-prefixing them (parameter `_`-prefixes are fine only when a trait signature requires the parameter).
- Keep gameplay deterministic where practical; isolate randomness behind small helpers or state-owned RNG.
- Avoid broad refactors bundled into focused changes — match each project's existing style and structure rather than imposing a new one.
- Don't add dependencies unless they remove real complexity or match an already-established pattern in that project.
- Every published game keeps a root-level `catalog_thumbnail.png` (16:9 title/menu capture); `publish.ps1` deploys it to `<game_slug>/catalog_thumbnail.png` for the WebHatchery catalog card.

### Screenshot capture harness (`macroquad-toolkit::capture`)

Games wire an env-var-driven headless capture mode so UI can be verified without interactive input: when `<PREFIX>_CAPTURE_PATH` is set, the game boots into a named scene (`begin_capture_scene`), simulates a fixed number of frames at a fixed timestep, writes a PNG, and exits (stubbed out entirely on `wasm32`). See `docs/screenshot_capture_harness_guide.md` for the full walkthrough and `carriage_run` for a reference per-game `scripts/capture_ui.ps1` wrapper.

### Cargo workspace specifics

Root `Cargo.toml` workspace `members = ["*", "kaiju_sim/kaiju_server"]` with `exclude` for the build outputs and `rust_management` (which contains `template/` and `archive/`, so those no longer need their own exclude entries). Release profile defaults to `opt-level = "z"` + `lto = true` for small WASM output, with per-package overrides (e.g. `dungeon_manager` uses `opt-level = 3`, `finallanding` uses `opt-level = "s"`). Adding a new top-level game directory with a `Cargo.toml` automatically joins the workspace via the `"*"` glob.

**Never set `RUSTFLAGS` in a build script or shell.** All wasm link flags live in the workspace `.cargo/config.toml`. A `RUSTFLAGS` env var *replaces* that list rather than merging with it, and cargo fingerprints the flag set — so two different flag sets mean two parallel copies of the entire wasm dependency graph (`macroquad`, `macroquad-toolkit`, `image`, …), each stale whenever the other was built last. `publish.ps1` exported `-C link-arg=--allow-undefined` for years while the config supplied `-C link-arg=--import-undefined`, so alternating a publish with a hand-run `cargo build --target wasm32-unknown-unknown` recompiled the toolkit every single time. Both flags are now in the config and nothing sets the env var. If a build needs a different flag, add it to `.cargo/config.toml`. (The per-repo CI workflows are the one exception — a game repo checked out standalone has no workspace config, so `rust-ci.yml` still sets `RUSTFLAGS` itself.)

Games in the root `Cargo.toml`'s `exclude` list (`dragons_den`, `mytherra`, `nft_adventurers`, `dungeon_manager_2d`) are each their own workspace, so they get their own profile resolution and share none of the cached dependency builds — expect a from-scratch toolkit compile on those.

### Web shell (`web/`)

Game `index.html` files are **generated at publish time**, not hand-maintained. `web/index.template.html` is the single page shell and `web/storage.js` is the single localStorage bridge for toolkit persistence; each game supplies a root `game_page.json` with its title/prose/controls/details, and `publish.ps1` renders the two together into the WebGL package. See `web/README.md` for the schema and the `index.custom.css` / `index.custom.js` escape hatches.

Don't add an `index.html` to a game directory — edit `game_page.json` (or the template, for anything that should apply everywhere). `mq_js_bundle.js`, `sapp_jsutils.js`, `storage.js`, and `clipboard.js` are all deployed once to `shared-assets/runtime/` and referenced from there; per-game copies are deleted by the publish pipeline. `kaiju_sim` is the one deliberate exception (`"storage_js": "custom"`) — see `kaiju_sim/STORAGE_BRIDGE_TODO.md`.

There are deliberately **no per-game CSS/JS escape hatches**. Behaviour games used to hand-roll (canvas focus-on-click, context-menu suppression, arrow/space scroll prevention, fullscreen + DPI resync) lives in the template for everyone; anything game-specific is data in `game_page.json` (e.g. `pointer_lock`).

### DPI / display scaling

`screen_width()`, `screen_height()`, and `mouse_position()` are **logical** pixels (macroquad divides them by the DPI scale), but a `Camera2D`/`Camera3D` `viewport` goes straight to `glViewport`, which takes **physical framebuffer** pixels. On a display at 125–160% scaling the two differ, and mixing them renders the frame shrunk into the bottom-left corner while hit-testing still spans the whole window. Keep all layout and mouse math logical, and convert only at the viewport boundary via `VirtualUi::viewport()` or `macroquad_toolkit::ui::logical_viewport()`. Never pass `screen_width()` to a `viewport` field directly.

### Other repo landmarks

- `standing.md` — a maintained ranking of active top-level games by implementation scale/complexity; useful for gauging how large/mature a given project is before diving in.
- `archive/` — retired/prototype projects, excluded from the workspace and from workspace-wide scripts. Four of them (`fracture`, `god_manager`, `nft_adventurers`, `quiteville`) are still their own git repos and are gitignored here so they don't become broken gitlinks.
- `web/shared.css` — shared stylesheet copied into `Release/` by `build_all_webgl.ps1` for the catalog page and each game's `index.html`, alongside `bug-report.css`/`bug-report.js`.
