# Cargo workspace rollout verification

Verified on Windows on 2026-09-21 with Cargo 1.98.0 and sccache 0.17.0.

## Configuration and scope

- 41 explicit root-workspace packages; Mytherra and Tarrowyn retain their
  intentional multi-crate workspaces.
- 49 direct or workspace-level Macroquad dependency declarations pinned to
  `=0.4.16`, covering active games, toolkit, template, samples and archived games.
- Root, Mytherra and Tarrowyn authoritative locks resolve Macroquad 0.4.16.
- `python rust_management/sync-workspace.py --check` passes.
- Shared standards documents were synced; `docs/check-project-docs.ps1` passes.
- Root rust-analyzer settings route checks and build-script discovery through
  the launcher. Directly opened game folders can use `configure-editor.ps1`.

## Build pool

`scripts/test-cargo-pool.ps1` passed all five OS-process checks: distinct
concurrent slots, bounded saturation, same-project serialization, lease recovery
after abrupt process termination, and caller-environment restoration on failure.

Cargo's error exit code was preserved (101 for an unknown package). The launcher
also produced valid Cargo JSON under Windows PowerShell 5.1, matching the editor
invocation. PowerShell script callers must quote `'--'` when forwarding compiler,
test or game arguments; canonical examples document this shell requirement.

A Realmseed native executable was staged and launched. A concurrent lease for
the same game succeeded while it was running, demonstrating that interactive
play retained neither its project lease nor a build slot. The verification-owned
process was stopped and its staged executable cleaned up. The shared capture
wrapper also built/captured Realmseed's menu successfully, then repeated the
capture with `-SkipBuild` from the recorded slot. The capture is in the game's
`docs/verification/ui_menu.png`.

## Compilation and publishing

- Root `cargo.ps1 check --workspace --all-targets --locked`: passed, including
  Idle Hands, without exclusions or game-local environment configuration.
  Existing dead-code warnings in Alchemy Tower and Last Assembly remain.
- Mytherra and Tarrowyn: `check --workspace --all-targets --locked` passed.
- Realmseed native build and Apartment WebGL build passed in separate slots.
- Apartment publisher native/WebGL dry run passed; the integrated pooled native
  dry run and `-SkipBuild` reuse also passed. Dry runs still compile/package,
  so they acquire leases; deployment-only operations do not.
- Idle Hands: formatting check and the existing analytics-disabled regression
  passed. Its ordinary `publish.ps1` built Windows and WebGL, packaged assets,
  deployed to the configured Preview location and recorded the deployment.
- Idle Hands strict all-target/all-feature Clippy remains blocked by the
  pre-existing `clippy::some_filter` expression in `src/game_variant_ui.rs:46`.
  That unrelated UI source was not changed. Compilation and publishing passed.

Idle Hands no longer has `.cargo/config.toml`. Analytics is off unless explicitly
enabled with a complete nonempty optional configuration; ordinary builds need
no analytics environment. Its test script uses the pool, and documented demo
builds use the shared `demo` profile instead of a private target directory.

## Compiler cache

An initial cross-slot test exposed sccache 0.17 hashing slot-specific
`CARGO_TARGET_DIR`/`CARGO_BUILD_BUILD_DIR` environment values. The shared invocation
helper now passes equivalent Cargo CLI configuration while compiling and restores
the lease environment afterward for metadata/output consumers.

Two release builds of the actual toolkit in different slots then recorded
85 Rust cache hits. The first took 30.08 seconds and the second 17.12 seconds;
these are smoke-test timings under other workstation activity, not a benchmark.
No source copies, substitute manifests or per-test build directories were used.
The cache is bounded to 10 GB by default; slot outputs still occupy disk.

## Boundaries

No catalog-wide production publish or legacy-target deletion was performed.
Archived games received matching pins and synced guidance but were not rebuilt.
Direct raw Cargo builds bypass the launcher, so developers and agents must follow
the synced command guidance. Slots coordinate build outputs, not simultaneous
edits to shared toolkit source or dependency lockfiles. Existing project-local
lockfiles on root members remain unused by the shared workspace; exact manifest
pins also apply when a game is resolved independently in CI.
