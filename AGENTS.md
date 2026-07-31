# RustGames Agent Instructions

The canonical text lives in **`docs/AGENTS.md`** — read it there.

`docs/` is the single source for the four documents synced verbatim into every
game project (`AGENTS.md`, `CODE_STANDARDS.md`, `MACROQUAD_TOOLKIT.md`,
`GAME_DEVELOPMENT_GUIDE.md`). `rust_management` is not a Cargo project, so
`sync-project-docs.ps1` never reaches this directory and a copy kept here drifts
silently — as this one had. Edit `docs/AGENTS.md`, never a copy.

For guidance specific to this repo — the publish and build tooling, the shared
web shell, `template/`, `archive/` — see `CLAUDE.md`.
