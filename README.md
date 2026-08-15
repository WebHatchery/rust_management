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
