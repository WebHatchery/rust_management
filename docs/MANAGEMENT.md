# Rust management tooling reference

Read the relevant section when changing management tooling. Shared game rules live in [AGENTS.md](AGENTS.md) and its triggered references. Unqualified tooling paths below are relative to `rust_management/`, not this document directory.

## What this is

`RustGames` is a workspace of independent Rust + `macroquad` games (WebGL + native Windows) published to the WebHatchery games catalog. The workspace root itself is **not** a git repository — each game subdirectory (`alchemy_tower/`, `apartment/`, `dungeon_manager/`, etc.) is its own independent git repo. A root `Cargo.toml` ties them together as a Cargo workspace purely for convenience (shared `target/`, one `cargo check` across everything); it does not imply shared versioning or releases.

## Directory layout

**`rust_management/` is its own git repo and holds the shared management sources:** the publish/build tooling, `docs/`, `template/`, `archive/`, `title_screeshots/`, and `web/` (the shared page shell plus `shared.css` and the bug-report widget).

The **workspace root** (`rust_management`'s parent) holds only the game repos, `macroquad-toolkit/`, `Cargo.toml`/`Cargo.lock`, and the build outputs `target/`, `Release/`, `publish-logs/`.

The `*.ps1` files at the workspace root are **pointers** that forward here — run any command from either location. They carry a real `param()` block on purpose: forwarding with `@args` corrupts switches (PowerShell splits `-Production:$false` into `-Production:` and `False`, and the target then binds a bare `-Production` as `$true`, silently deploying to production). If you add a parameter to a script here, mirror it in the root pointer.

Scripts here resolve two different roots: `$ManagementRoot` (`$PSScriptRoot`) for tooling and web assets, and `$WorkspaceRoot` (its parent) for games, `Release/` and `publish-logs/`. Use the right one.

Two non-game members matter most:
- **`macroquad-toolkit/`** — a shared crate (path dependency `{ path = "../macroquad-toolkit" }`) providing input, UI widgets, asset/texture management, camera, event bus, color palette, sprites, persistence, pathfinding, and the screenshot-capture harness used by every game.
- **`template/`** — a working starter game pre-wired to the toolkit; copy it as the starting point for a new game (see its README's "Rename For A New Game" steps).

`docs/` is the canonical source for five documents that are duplicated verbatim into every game project: `AGENTS.md`, `CODE_STANDARDS.md`, `UI_STYLE.md`, `MACROQUAD_TOOLKIT.md`, `GAME_DEVELOPMENT_GUIDE.md`. Never hand-edit a project-local copy's shared content — put project-specific guidance in that project's README or a `PROJECT_AGENTS.md` instead, and use the sync scripts below to manage the shared files.

## Commands

There's no top-level `cargo test`/`cargo build` workflow spanning "the product" — each game is built, tested, and shipped independently from its own directory.

**Per-game loop** (run from inside a game directory, e.g. `apartment/`):
```powershell
..\rust_management\cargo.ps1 build                          # native debug build
..\rust_management\cargo.ps1 run                            # run the game
..\rust_management\cargo.ps1 test                           # run tests; cargo test <name> for a single test
cargo fmt -- --check                 # formatting check (CI enforces this)
..\rust_management\cargo.ps1 clippy --all-targets --all-features '--' -D warnings   # lint (CI treats warnings as errors)
..\rust_management\cargo.ps1 build --release --target wasm32-unknown-unknown      # WebGL/WASM build
```

**Local validation and publishing** - use [CODE_STANDARDS.md section 8.3](CODE_STANDARDS.md#83-validation): strict formatting/Clippy, source-size gates, focused relevant tests, and affected UI only. Broaden tests for cross-cutting risk or integration/release acceptance. Local commits do not require publishing.

Each game's `publish.ps1` forwards to the root publisher with `-RustGamePublish -ProjectDir <path>`. It may deploy or contact external services: run only with user authorization. `-WebGLOnly`, `-WindowsOnly`, `-DeployOnly`, `-Production` (`-p`), `-FTP`, and `-DryRun` are publishing options, not substitutes for authorization. Do not batch-publish merely to validate a game.

**itch.io publishing** is intentionally separate from `publish.ps1`. Each game
has a `publish-itch.ps1` wrapper and an `itch.json` file when it has an itch
page. The wrappers forward to `rust_management/publish-itch.ps1`, which stages
the already-generated `dist/` artifacts as a standalone HTML5 package and
publishes the configured HTML5 and Windows Butler channels. Run the ordinary
publisher first, then from the game directory:

```powershell
.\publish.ps1
.\publish-itch.ps1 -DryRun
.\publish-itch.ps1 -Preview
.\publish-itch.ps1 -Status
.\publish-itch.ps1
```

`-Preview` uses Butler's per-file channel diff and never uploads. `-DryRun`
stages and validates the package, then asks Butler to list what would be sent.
Never add itch upload behavior to the ordinary publisher or to
`publish-all.ps1`; external uploads must remain explicit. Keep Butler
credentials in its local credential store, never in `itch.json` or a script.

**Workspace-wide scripts** (in `rust_management/`, also runnable from the workspace root via the pointers):
- `.\build_all_webgl.ps1` — runs every game's `publish.ps1`, collects WebGL + Windows artifacts into `Release/`, generates a catalog `index.html`.
- `.\publish-all.ps1` / `.\publish-all-ftp.ps1` — runs `publish.ps1` in every game subdirectory (excludes `template`, `target`, `assets`, `macroquad-toolkit`).
- `.\publish-all-ftp.ps1 -ChangedOnly [-DryRun] [-Fetch]` — uses `prod-drift.ps1` to publish only local production updates and games never deployed; see the README for comparison rules.
- `.\docs\check-project-docs.ps1` [-ProjectRoot <names>] — verifies each game's local copy of the five shared docs matches the canonical one in `docs/`; non-zero exit on drift.
- `.\docs\sync-project-docs.ps1` [-ProjectRoot <names>] [-IncludeWorkspaceRoot] — overwrites project-local copies from `docs/`.
- `.\sync-rust-ci-workflows.ps1` [-Project <names>] [-WhatIf] — syncs the shared `rust-ci.yml` GitHub Actions workflow across top-level projects. The workflow is a here-string inside the script, so **edit it there, never in a game's `.github/`** — a re-sync overwrites every project-local copy. Two per-project maps in the script hold everything a game needs beyond the shared shape, so a re-sync reproduces those instead of erasing them: `$ExtraCheckouts` fetches a sibling repo (CI builds each game from a standalone checkout, so a path dependency outside its own repo cannot otherwise resolve — `tb_realms` uses this for `mytherra`), and `$WorkspaceScopes` widens fmt/clippy/test for a multi-crate game (`mytherra`, whose server/protocol/persistence crates the default root-package checks would skip; build steps stay unscoped because a native-only crate cannot target wasm). The sync is idempotent.
- `python find_large_rs_files.py [root_dir] [--min-lines 500]` — audits `.rs` files approaching/over the size limit.
- `.\check-loops.ps1 [-ArmedOnly]` — lists which live Claude Code sessions have an armed `/loop`, and in which game directory. Loop state is session-scoped (`CronList` only sees the current session; a self-paced `/loop` exposes nothing at all), so this reconstructs it from `~/.claude/sessions` plus each session's transcript. Read-only.
- `.\capture-title-screenshots.ps1 -Publish` — refreshes each game's title-screen capture into `catalog_thumbnail.png`.
- `..\macroquad-toolkit\scripts\capture_ui.ps1 -Scenes <scene1,scene2>` (run from inside a game dir) — builds the game and captures headless UI screenshots per scene for visual verification; derives package/exe/env-prefix from `cargo metadata`, so no arguments needed beyond `-Scenes` (pass `-Prefix` if the game's env-var prefix differs from its package name, e.g. `carriage_run` → `CARRIAGE`).

## Architecture

### Per-game structure and hard constraints

Use [CODE_STANDARDS.md](CODE_STANDARDS.md) for module boundaries, data,
state, testing, source-size, platform, and validation policy;
[UI_STYLE.md](UI_STYLE.md) for composition and visual review; and
[GAME_DEVELOPMENT_GUIDE.md](GAME_DEVELOPMENT_GUIDE.md) for setup patterns.
Do not duplicate those authorities in management instructions.

### Screenshot capture harness (`macroquad-toolkit::capture`)

Games wire an env-var-driven headless capture mode so UI can be verified without interactive input: when `<PREFIX>_CAPTURE_PATH` is set, the game boots into a named scene (`begin_capture_scene`), simulates a fixed number of frames at a fixed timestep, writes a PNG, and exits (stubbed out entirely on `wasm32`). See `docs/screenshot_capture_harness_guide.md` for the full walkthrough and `carriage_run` for a reference per-game `scripts/capture_ui.ps1` wrapper.

### Cargo workspace specifics

Workspace membership is explicit in `workspace/Cargo.toml`; the root manifest,
lockfile and `.cargo/config.toml` are installed with `python sync-workspace.py`.
Record intentional root lockfile updates with `--capture-lock`; check deployment
and version policy with `--check`. Do not change membership to avoid build locks.
Mytherra and Tarrowyn remain intentional multi-crate workspaces.

Use `cargo.ps1` for local compilation, checks, tests, Clippy and interactive run.
The launcher leases one of three persistent slots (four compiler jobs each),
uses sccache when installed, and restores the caller's environment. Publishing
and capture integrate the pool automatically. Interactive games run staged
executables after releasing the compiler slot. All games and the toolkit pin
Macroquad exactly to `=0.4.16`, checked before publishing the shared runtime.

Shared WASM flags live in `workspace/config.toml`; do not set `RUSTFLAGS` in
local scripts. CI in standalone checkouts supplies its own matching flags.
See [docs/CARGO_WORKSPACE.md](CARGO_WORKSPACE.md) for setup, editor routing,
cache policy, concurrency limits, and dependency maintenance.

### Web shell (`web/`)

Game `index.html` files are **generated at publish time**, not hand-maintained. `web/index.template.html` is the single page shell and `web/storage.js` is the single localStorage bridge for toolkit persistence; each game supplies a root `game_page.json` with its title/prose/controls/details, and `publish.ps1` renders the two together into the WebGL package. See [web/README.md](../web/README.md) for the schema; per-game CSS/JS escape hatches are not supported.

Don't add an `index.html` to a game directory — edit `game_page.json` (or the template, for anything that should apply everywhere). `mq_js_bundle.js`, `sapp_jsutils.js`, `storage.js`, and `clipboard.js` are all deployed once to `shared-assets/runtime/` and referenced from there; per-game copies are deleted by the publish pipeline. `kaiju_sim` is the one deliberate exception (`"storage_js": "custom"`) — see `kaiju_sim/STORAGE_BRIDGE_TODO.md`.

There are deliberately **no per-game CSS/JS escape hatches**. Behaviour games used to hand-roll (canvas focus-on-click, context-menu suppression, arrow/space scroll prevention, fullscreen + DPI resync) lives in the template for everyone; anything game-specific is data in `game_page.json` (e.g. `pointer_lock`).

### DPI / display scaling

`screen_width()`, `screen_height()`, and `mouse_position()` are **logical** pixels (macroquad divides them by the DPI scale), but a `Camera2D`/`Camera3D` `viewport` goes straight to `glViewport`, which takes **physical framebuffer** pixels. On a display at 125–160% scaling the two differ, and mixing them renders the frame shrunk into the bottom-left corner while hit-testing still spans the whole window. Keep all layout and mouse math logical, and convert only at the viewport boundary via `VirtualUi::viewport()` or `macroquad_toolkit::ui::logical_viewport()`. Never pass `screen_width()` to a `viewport` field directly.

### Other repo landmarks

- `standing.md` — a maintained ranking of active top-level games by implementation scale/complexity; useful for gauging how large/mature a given project is before diving in.
- `archive/` — retired/prototype projects, excluded from the workspace and from workspace-wide scripts. Four of them (`fracture`, `god_manager`, `nft_adventurers`, `quiteville`) are still their own git repos and are gitignored here so they don't become broken gitlinks.
- `web/shared.css` — shared stylesheet copied into `Release/` by `build_all_webgl.ps1` for the catalog page and each game's `index.html`, alongside `bug-report.css`/`bug-report.js`.
