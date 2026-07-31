# Shared Project Documents

This folder is the canonical source for the shared RustGames project documents:

- `AGENTS.md`
- `CODE_STANDARDS.md`
- `MACROQUAD_TOOLKIT.md`
- `GAME_DEVELOPMENT_GUIDE.md`

Project-local copies are kept next to each game project's `Cargo.toml` so a downloaded project still includes the standards an agent should follow. These managed files should remain identical to the canonical copies in this folder.

## Reference Documents

These live here for the whole catalog but are **not** synced into each game — read them as needed:

- `COMMIT_STYLE.md` — git commit message conventions for the Rust games (Mytherra as the exemplar).
- `GDD_TEMPLATE.md` — starting structure for a new game's design document.
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

The sync script overwrites project-local copies with the canonical files from this folder. By default, it scans game projects under the workspace root and skips the workspace root itself. A game project is a Cargo project with `publish.ps1`.

Before syncing, move project-specific guidance into a project README or another local documentation file such as `PROJECT_AGENTS.md`. The managed shared documents are meant to stay identical across projects.

To include the workspace root:

```powershell
.\docs\sync-project-docs.ps1 -IncludeWorkspaceRoot
```

To check or sync only specific projects:

```powershell
.\docs\check-project-docs.ps1 -ProjectRoot ai_defense,frontier
.\docs\sync-project-docs.ps1 -ProjectRoot ai_defense,frontier
```
