# WebHatchery Rust Games Management

This repository owns the shared tooling and documentation for the WebHatchery
Rust games catalog. It is not a game and is intentionally excluded from the
Cargo workspace.

New collaborators should begin with the
[onboarding guide](docs/onboarding/README.md). It covers:

- required software and Windows/Rust setup;
- the multi-repository folder layout and clone order;
- the shared `macroquad-toolkit` and game architecture;
- local development, validation, screenshots, and documentation sync;
- preview, production, and FTP publishing;
- required and optional environment values; and
- the Git and pull-request workflow used across the catalog.

Repository maintainers should also read [CLAUDE.md](CLAUDE.md), which documents
the internals of the management scripts and shared web shell.

For new games and screen changes, read [UI_STYLE.md](docs/UI_STYLE.md) before
building the UI. It covers gameplay focus, hierarchy, contextual information,
template adaptation, and visual review, and is synced alongside the code
standards into game projects.

## Repository map

| Path | Purpose |
| --- | --- |
| `docs/` | Canonical standards and catalog-wide reference documents |
| `docs/onboarding/` | Start-to-finish collaborator setup and workflow |
| `publish.ps1` | Shared per-game build, package, deploy, and FTP implementation |
| `template/` | Working starter crate for a new game |
| `web/` | Generated page template, shared CSS, and browser bridges |
| `scripts/` | One-off and maintenance helpers |
| `archive/` | Retired prototypes, excluded from normal workspace operations |

The scripts at the RustGames workspace root are forwarding wrappers. Their
implementations live here unless a document says otherwise.

## Publish games with production drift

Run from this directory or the RustGames workspace root:

```powershell
.\publish-all-ftp.ps1 -ChangedOnly -DryRun # Check Roost and preview the batch
.\publish-all-ftp.ps1 -ChangedOnly         # Build and FTP-publish local updates
.\publish-all-ftp.ps1 -ChangedOnly -Fetch  # Refresh Git tracking refs before checking
```

This uses `prod-drift.ps1` to compare each game's local checkout with its last
successful production deployment in Project Roost. It selects games with local
commits since deployment, uncommitted files, or no recorded production deployment.
Uncommitted changes are included in the build. Remote-only updates are reported
and skipped; fetch does not pull or merge them into the local checkout.
With `-ChangedOnly -DryRun`, only the selection is previewed: no builds or uploads run.

Shared assets upload once before the selected games, and the catalog uploads once
after all selected games succeed. Nothing uploads when no games need publishing.
Roost errors, unavailable comparisons, date-based estimates, and deployed commits
that are not ancestors of local HEAD stop the batch before any upload. Failures
return a nonzero exit code, and each run writes a transcript in `../publish-logs/`.

`-ChangedOnly` requires fresh builds and cannot be combined with `-SkipBuild`.
Without `-ChangedOnly`, the original full-catalog FTP publish remains available.
The comparison tracks game repositories; changes only in the shared toolkit or
management/web tooling still require a full publish to rebuild affected games.

## Concurrent Rust builds

Use the shared [Cargo build pool](docs/CARGO_WORKSPACE.md) for local compilation, tests, editor checks and game runs. Canonical workspace configuration and the exact Macroquad runtime policy live in `workspace/`; deploy/check them with `sync-workspace.py`.
