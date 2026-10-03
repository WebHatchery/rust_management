# Shared Project Documents

`docs/` owns the five documents distributed verbatim beside each game's
`Cargo.toml`: [AGENTS.md](AGENTS.md), [CODE_STANDARDS.md](CODE_STANDARDS.md),
[UI_STYLE.md](UI_STYLE.md), [MACROQUAD_TOOLKIT.md](MACROQUAD_TOOLKIT.md), and
[GAME_DEVELOPMENT_GUIDE.md](GAME_DEVELOPMENT_GUIDE.md). Keep all five: downloaded
projects need locally available policy and API references.

## Loading guidance

`AGENTS.md` is the project entrypoint. Its task table requires references before
relevant work; copying a reference into a project does **not** itself load it
into model context. Do not routinely read all five or paste their checklists
into each other. The runtime decides which instruction files are auto-loaded;
this repository cannot guarantee its exact context, token count, or billing.

- Coding/data/behavior: code standards; screens/input/rendering: also UI style.
- Shared capabilities: relevant toolkit modules; setup/migration: development
  guide and template README; validation/capture: code standards sections 8.3/12.
- Management work starts with the root AGENTS pointer and `CLAUDE.md`; its
  detailed operational reference is [MANAGEMENT.md](MANAGEMENT.md), read by task.
  The workspace parent `CLAUDE.md` also imports `rust_management/CLAUDE.md` via
  an `@` directive. Runtimes honoring that import load the compact management
  entrypoint even in game sessions; the parent pointer is maintained separately.
- Project README/GDD and `PROJECT_AGENTS.md` retain local requirements. On-demand
  reading reduces repeated background but requires following the entrypoint's
  triggers; it does not make the referenced rules optional.

New collaborators can follow [onboarding](onboarding/README.md) once, then use
its individual pages as references. Compare measured lines/words/bytes when
reviewing documentation size; token estimates and costs depend on model,
serialization, context reuse, and caching.

## Reference Documents

These live here for the whole catalog but are **not** synced into each game — read them as needed:

- `MANAGEMENT.md` - build/publish tooling inventory, generated CI, web shell, archive, and DPI details.
- `CARGO_WORKSPACE.md` - build pool, canonical configuration, caches, and dependency policy.
- `COMMIT_STYLE.md` — git commit message conventions for the Rust games (Mytherra as the exemplar).
- `GDD_TEMPLATE.md` — starting structure for a new game's design document.
- `itch-publishing-lessons.md` — reusable lessons and checklist for publishing Rust games to itch.io.
- `screenshot_capture_harness_guide.md` — wiring headless UI screenshot capture into a game.

## Check For Drift

```powershell
.\docs\check-project-docs.ps1
```

The check script compares every discovered game project copy against the canonical files in this folder. It exits with a non-zero status when a copy is missing or different.

## Sync Project Copies

```powershell
.\docs\sync-project-docs.ps1
```

The sync script overwrites project-local copies with the canonical files from this folder. Check ownership and local diffs first; coordinate with active tasks and avoid a default mass sync during concurrent work. By default, it scans game projects under the workspace root and skips the workspace root itself. A game project is a Cargo project with `publish.ps1`.

This includes the nested starter template and archived Cargo games with
`publish.ps1`. To refresh only the starter used by new games, run these from
`rust_management/` (relative project targets are resolved from the workspace
root, not the current directory):

```powershell
.\docs\sync-project-docs.ps1 -ProjectRoot rust_management/template
.\docs\check-project-docs.ps1 -ProjectRoot rust_management/template
```

Before syncing, consolidate project-specific guidance into a project README or another local documentation file such as `PROJECT_AGENTS.md`. The managed shared documents are meant to stay identical across projects.

To include the workspace root:

```powershell
.\docs\sync-project-docs.ps1 -IncludeWorkspaceRoot
```

To check or sync only specific projects:

```powershell
.\docs\check-project-docs.ps1 -ProjectRoot apartment,frontier
.\docs\sync-project-docs.ps1 -ProjectRoot apartment,frontier
```

## Safe rollout and validation

Use `check-project-docs.ps1 -ProjectRoot <names>` (or sync with `-Check`) for a
read-only drift check. A nonzero exit reports missing/different copies; it does
not update them. The sync script has no `-WhatIf`/`-DryRun`: do not invent those
flags or confuse a publishing dry run, which may build, with a docs check.

Target names are relative to the **workspace root**, so the starter is
`rust_management/template`. New games inherit the updated five files when the
starter is copied. Existing consumers require an explicitly targeted sync and
review/commit in each owning repository; updating management alone changes none
of them. Existing `docs/<shared-name>.md` duplicates are also refreshed when
present. The default recursive scan includes archived games; `-IncludeWorkspaceRoot`
adds the root when eligible. `rust_management` itself has no Cargo manifest and
uses its root AGENTS pointer, not a managed copy.

For a documentation-only slice: review requirements and links/anchors, run
`git diff --check`, sync/check the starter only, and inspect the diff. Check
selected consumers read-only to report pending propagation. Do not publish games
solely to validate prose or sync active consumers without coordinating ownership.
