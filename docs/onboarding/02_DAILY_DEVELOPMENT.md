# Daily development workflow

## Before changing code

1. Confirm which repository owns the change: game, toolkit, or management.
2. Pull or fetch the latest branch in every affected repository.
3. Read the game README/GDD and its local copies of `AGENTS.md`,
   `CODE_STANDARDS.md`, `UI_STYLE.md`, `MACROQUAD_TOOLKIT.md`, and
   `GAME_DEVELOPMENT_GUIDE.md`.
4. Check `git status` before editing; do not overwrite another person's work.
5. Create a focused branch as described in
   [05_GIT_COLLABORATION.md](05_GIT_COLLABORATION.md).

## Tight edit/test loop

Run commands inside the game you are changing:

```powershell
cargo fmt
..\rust_management\cargo.ps1 test
..\rust_management\cargo.ps1 clippy --all-targets --all-features '--' -D warnings
..\rust_management\cargo.ps1 run
```

For a single test:

```powershell
..\rust_management\cargo.ps1 test <test_name>
```

The launcher shares three persistent build slots and a compiler cache; all local
builds, including intentional standalone workspaces, follow this policy. See
[../CARGO_WORKSPACE.md](../CARGO_WORKSPACE.md) for sccache and editor setup.

## Required implementation rules

- Use Rust, Macroquad, and `macroquad-toolkit` by default.
- Check whether a reusable runtime, input, rendering, asset, camera, persistence,
  or platform capability belongs in the toolkit before duplicating it locally.
- Keep every `.rs` file at or below 800 physical lines. The preferred range is
  200–400 lines; split by responsibility rather than compressing formatting.
- Use named module files (`foo.rs` plus `foo/bar.rs`), never new `mod.rs` files.
- Keep UI as a view that returns actions/intents; apply mutations in game/state
  logic.
- Follow [../UI_STYLE.md](../UI_STYLE.md) for screen composition. Plan the
  current decision, emphasize gameplay, and defer secondary information.
- Put content and balance data in JSON under `assets/` where practical.
- Route generic JSON loading through `macroquad_toolkit::data_loader`.
- Make every required browser interaction possible with visible touch/click
  controls. Keyboard shortcuts may supplement, not replace, touch controls.
- Keep all tests and test-only helpers in each crate's `tests/` directory beside
  its `Cargo.toml`, including workspace members. Exercise the public library API;
  binary games expose testable logic through `src/lib.rs` used by `main.rs`.
- Do not add test modules, `#[cfg(test)]`, or test helpers under `src/`. Migrate
  existing source-tree tests separately before expanding coverage (§11.4).
- Focus on calculations, state transitions, and JSON loading with simple tests
  that read like rules. UI and rendering generally do not need unit tests.
- Strongly target no more than five `#[test]` cases per major feature across all
  its suites. Use table-driven assertions for related inputs, preserve useful
  regressions, and explain distinct coverage that needs more cases before
  committing (§11.3).
- Keep a root `catalog_thumbnail.png`, preferably a 16:9 title/menu capture.

The complete rules live in [../CODE_STANDARDS.md](../CODE_STANDARDS.md),
[../UI_STYLE.md](../UI_STYLE.md), and
[../GAME_DEVELOPMENT_GUIDE.md](../GAME_DEVELOPMENT_GUIDE.md).

## Assets and web pages

Game page metadata belongs in `game_page.json`. Publishing combines it with
`rust_management/web/index.template.html` to generate `dist/webgl/index.html`.
Do not add or hand-edit a game-root `index.html` for a migrated game.

Static game assets live under `assets/`. If a game has `asset_registry.json`,
the publisher packages only its registered assets and configured packs. Without
one, publishing warns and copies the entire `assets/` tree. See
[../asset-registry.md](../asset-registry.md).

## Starting a new game

Start from the working template, not `cargo new`:

```powershell
Set-Location D:\WebHatchery\RustGames
Copy-Item .\rust_management\template .\<new-game-folder> -Recurse
Set-Location .\<new-game-folder>
```

Then initialize its independent Git repository, set the intended remote, and
follow the rename checklist in `rust_management/template/README.md`. Confirm the
package name, `game_page.json`, capture prefix, root thumbnail, toolkit path,
and data files before implementing features. Add the game to the explicit members in `rust_management/workspace/Cargo.toml`
and run `python rust_management/sync-workspace.py` before using Cargo.

Before expanding game content, complete the `UI_STYLE.md` screen brief in
the game's GDD or README and recompose the template's demo UI. Its collection
of panels and utility controls demonstrates integration, not the intended
visual hierarchy for the new game.

## Visual verification

Use [../UI_STYLE.md](../UI_STYLE.md) §9 to select scenes and assess focus,
readability, disclosure, and touch interaction at normal and minimum supported
sizes. Inspect the images after capture; a valid PNG alone is not UI approval.

Games with the capture harness can render deterministic UI scenes headlessly:

```powershell
.\scripts\capture_ui.ps1 -Scenes menu,gameplay
```

Or call the toolkit helper from the game directory:

```powershell
..\macroquad-toolkit\scripts\capture_ui.ps1 -Scenes menu,gameplay
```

Store accepted verification images directly in `docs/verification/`. Replace
an existing image when it represents the same scene/state. Read
[../screenshot_capture_harness_guide.md](../screenshot_capture_harness_guide.md)
before adding capture support to a game.

## End-to-end validation

After meaningful game changes, the sanctioned final check is the game wrapper:

```powershell
.\publish.ps1
```

It builds Windows and WebGL release artifacts, packages them, and deploys to the
configured preview root. For changes that cannot reasonably support one target,
use the narrow flag and state that clearly in the handoff:

```powershell
.\publish.ps1 -WebGLOnly
.\publish.ps1 -WindowsOnly
```

Do not run `publish-all.ps1`, `publish-all-ftp.ps1`, or
`build_all_webgl.ps1` merely to validate one game.

## Shared-document and CI maintenance

The five shared documents, including `UI_STYLE.md`, are edited only in
`rust_management/docs/`, then synced into games:

```powershell
Set-Location D:\WebHatchery\RustGames\rust_management
.\docs\check-project-docs.ps1
.\docs\sync-project-docs.ps1 -ProjectRoot <game-folder>
```

Do not hand-edit a synced game copy. Put game-specific agent guidance in its
README or `PROJECT_AGENTS.md`.

The shared GitHub Actions workflow is generated by
`sync-rust-ci-workflows.ps1`. Edit the here-string/maps in that script, then
sync; do not independently customize a generated game workflow.

Audit Rust file sizes with:

```powershell
python .\find_large_rs_files.py .. --min-lines 500
```
