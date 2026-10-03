# Daily development workflow

## Before changing code

1. Confirm which repository owns the change: game, toolkit, or management.
2. Read the game README/GDD and `PROJECT_AGENTS.md` if present, then `AGENTS.md`.
   Load its task-triggered references before the relevant work, not the entire
   documentation set on every turn.
3. Inspect branch, status, and diffs; preserve existing/concurrent work. Follow
   [05_GIT_COLLABORATION.md](05_GIT_COLLABORATION.md) for ownership and commit cadence.
   Agents stay on `master` unless the user requests a branch; coordinate updates
   to the branch without overwriting active edits.

## Tight edit/test loop

Run commands inside the game you are changing:

```powershell
cargo fmt
..\rust_management\cargo.ps1 test <relevant_test_filter>
..\rust_management\cargo.ps1 clippy --all-targets --all-features '--' -D warnings
..\rust_management\cargo.ps1 run
```

Select an existing test target/filter that covers the slice; unfiltered full
suites are for the broader triggers in section 8.3. For a single test:

```powershell
..\rust_management\cargo.ps1 test <test_name>
```

The launcher shares three persistent build slots and a compiler cache; all local
builds, including intentional standalone workspaces, follow this policy. See
[../CARGO_WORKSPACE.md](../CARGO_WORKSPACE.md) for sccache and editor setup.

## Required implementation rules

Read [../CODE_STANDARDS.md](../CODE_STANDARDS.md) for code/data/behavior work,
[../UI_STYLE.md](../UI_STYLE.md) before screen/input/rendering work, and the
relevant [toolkit modules](../MACROQUAD_TOOLKIT.md#modules) before duplicating
shared capabilities. These are the authorities, not optional background reading.

Commit each coherent, buildable feature slice after diff review and required
checks, before starting the next. Focused relevant tests are the ordinary slice
default alongside formatting, strict Clippy, and source-size checks. Broader
suites need a cross-cutting, integration, or release reason. See
[validation](../CODE_STANDARDS.md#83-validation) for scope,
documentation-only checks, and handling verified baseline failures.

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

## Integration and release validation

Broaden tests at meaningful integration boundaries or for cross-cutting risk;
build Windows/WASM as relevant to platform or release acceptance. Review only
changed UI and affected states. Reuse valid unchanged results.

Publishing is separate from local validation, never a per-slice commit gate.
`publish.ps1` builds/packages and can deploy or contact external trackers; run
it only with user authorization. Report deliberately unrun publishing clearly.
Do not batch-publish games to validate one slice. The full policy is
[section 8.3](../CODE_STANDARDS.md#83-validation).

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
