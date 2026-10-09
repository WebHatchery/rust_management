# Rust management agent guidance

Read [docs/AGENTS.md](docs/AGENTS.md) for shared rules and task-triggered references.
`rust_management` is an independent Git repository, **not a Cargo project**.
The parent is a Cargo workspace of independently versioned games and toolkit.

- Change canonical shared docs in `docs/`; never hand-edit their game copies.
  Keep the starter copies identical via a **template-only** sync. Read
  [docs/README.md](docs/README.md) before syncing consumers; a default sync
  overwrites game, template, and archived copies. Coordinate active work first.
- Use `$ManagementRoot` for tooling/web assets and `$WorkspaceRoot` for games,
  `target/`, `Release/`, and `publish-logs/`. Root PowerShell scripts are forwarding
  pointers: mirror parameter changes in their real `param()` blocks; `@args`
  forwarding can corrupt switches and accidentally select production.
- Shared testing policy: games are prototypes, so agents write no tests by
  default, even once released
  ([CODE_STANDARDS §11](docs/CODE_STANDARDS.md#11-testing-policy)). Keep every
  summary of it consistent with that section.
- Validate only the affected scope. Prose changes need documentation checks,
  not game builds. Do not batch-publish or deploy externally without authorization.
  Commit each validated coherent slice per the shared instructions.

| Work | Read before editing |
| --- | --- |
| Build/publish scripts, script inventory, archive/layout | Relevant [management tooling reference](docs/MANAGEMENT.md) sections and [README.md](README.md) |
| Shared docs, starter guidance, distribution | [docs/README.md](docs/README.md); [template/README.md](template/README.md) when changing the starter |
| Cargo pool, workspace, dependency versions, editor routing | [docs/CARGO_WORKSPACE.md](docs/CARGO_WORKSPACE.md) |
| Shared CI | [management commands](docs/MANAGEMENT.md#commands): edit `sync-rust-ci-workflows.ps1` source/maps, not generated workflows |
| Web shell, browser bridges, game page schema | [web/README.md](web/README.md); generated pages come from `web/index.template.html` and `game_page.json` |
| Runtime assets / packaging | [docs/asset-registry.md](docs/asset-registry.md) |
| Capture integration | [docs/screenshot_capture_harness_guide.md](docs/screenshot_capture_harness_guide.md) |
| itch.io release | [docs/onboarding/04_PUBLISHING.md](docs/onboarding/04_PUBLISHING.md) and [docs/itch-publishing-lessons.md](docs/itch-publishing-lessons.md) |
