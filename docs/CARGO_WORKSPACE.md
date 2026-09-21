# Shared Cargo workspace and concurrent builds

The versioned configuration lives in `rust_management/workspace/`. The root
`Cargo.toml`, `Cargo.lock`, and `.cargo/config.toml` are deployed copies; the
root is not a Git repository. Shared dependency source downloads remain in
Cargo home. Compiled dependencies are reused within three persistent build
slots, with sccache providing an additional shared compilation cache.

## Daily commands

From a game directory:

```powershell
..\rust_management\cargo.ps1 check --locked
..\rust_management\cargo.ps1 test --locked
..\rust_management\cargo.ps1 clippy --locked --all-targets --all-features '--' -D warnings
..\rust_management\cargo.ps1 run --locked
..\rust_management\cargo.ps1 build --locked --release --target wasm32-unknown-unknown
cargo fmt -- --check
```

From the workspace root, use `rust_management\cargo.ps1 check -p <package>`.
The launcher's remaining arguments are Cargo arguments; pass game/test arguments
after **quoted** `'--'`. PowerShell consumes an unquoted `--` when calling a
script, so use `cargo.ps1 test '--' --nocapture`, for example. Do not use raw `cargo build/check/test/clippy/run` during
concurrent local work. Cargo formatting, metadata and dependency maintenance
commands do not consume a build slot. CI in standalone checkouts still uses Cargo.

Put the Cargo subcommand first; custom aliases and leading `+toolchain` options
are rejected so they cannot accidentally bypass pooling.

The pool reserves `target/pool/slot-1` through `slot-3`, tries the project's
previous successful slot first, and takes another free slot if necessary.
Each slot runs at most four compiler jobs by default. A fourth concurrent build
waits, with a 30-minute timeout. Concurrent operations for the same project
serialize before requesting a slot. File locks are owned by the OS and released
if a process exits or crashes; never delete lock files to bypass another build.
The lease also isolates Cargo's intermediate build directory and restores the
caller's environment when finished. Locks do not isolate edits to shared source
or dependency resolution; coordinate toolkit changes and lockfile updates.

`run` builds first, stages the selected Windows executable under `target/run/`,
releases its slot, and launches it with the original working directory for assets
and saves. It removes that staged executable when the game exits. Select a single
binary with `--bin` or `--example` in multi-binary projects. Custom runners and
non-Windows executables are not supported by pooled `run`.

The normal publisher and shared screenshot wrapper acquire a slot automatically.
They keep it while consuming build outputs, so another build cannot replace those
outputs midway through packaging or capture. `-SkipBuild` reuses the last
successful slot for that operation; run once without it after adopting the pool.
Publishing dry runs still compile/package locally and reserve a slot; only
deployment-only operations skip it.
The capture wrapper supports a standalone toolkit checkout without management
tooling by using ordinary Cargo there.

## Editor checks

Configure the root editor workspace once:

```powershell
.\rust_management\configure-editor.ps1
```

For an editor opened directly on a game, run the same script with
`-ProjectRoot <game-directory>`. It preserves existing JSON settings and routes
rust-analyzer checks and build-script discovery through the launcher. Restart
rust-analyzer after changing its settings. Editor checks consume a normal slot;
opening more editors does not create more caches. The script records an absolute
local launcher path, so rerun it if the checkout moves. Settings files containing
JSON comments must be converted to ordinary JSON before running the script.

## Macroquad and browser runtime

Every game and the toolkit must declare `macroquad = "=0.4.16"` (or an inline
dependency table with `version = "=0.4.16"`). Preserve per-game features such as
audio. Exact direct pins work both locally and in independent CI checkouts.
`workspace/build-policy.json` records the agreed version. Publishing checks both
the manifest pin and the actual locked resolution before using the shared
browser runtime. A broad `"0.4"` requirement is not sufficient.

To upgrade, change the policy, run `python rust_management/sync-workspace.py --pin`,
update the root and intentional standalone lockfiles with Cargo, validate native
and WebGL builds, and capture the root lockfile. Upgrade and publish the shared
runtime as a coordinated catalog change. A deployment-only invocation cannot
prove an old staged WASM was built against a new version; rebuild those artifacts
when changing the version.

Idle Hands uses the same shared configuration; it has no game-local Cargo
configuration. Its optional analytics settings are not prerequisites for builds.
The shared `demo` profile inherits release settings while keeping feature-variant
outputs separate from full releases inside each pool slot.

The root lockfile is authoritative for members; any old per-game lockfile is not
used inside this workspace. Independent CI resolves the exact manifest pin.
Mytherra and Tarrowyn own real multi-crate workspaces and their own lockfiles;
they use the same build pool and version policy.

## Workspace membership and bootstrap

Members are explicit. Add a new game to `workspace/Cargo.toml` intentionally,
then install the configuration. Do not add `exclude` entries, empty workspaces,
placeholder manifests or copied source trees to get around a lock or a broken
member. A malformed registered member still needs to be fixed at its real source.

```powershell
# Restore the tracked workspace configuration after cloning all registered repos.
python rust_management/sync-workspace.py
# Verify deployed files, direct Macroquad pins, and authoritative lock versions.
python rust_management/sync-workspace.py --check
# After an intentional Cargo dependency update, record the real root lock.
python rust_management/sync-workspace.py --capture-lock
```

The installer refuses to overwrite a different existing root lockfile; capture
the intentional update first. Never edit the tracked lockfile by hand. Commit
the canonical configuration in rust_management together with coordinated game
manifest changes in their own repositories. Shared WASM linker flags stay in
`workspace/config.toml`; do not override them with `RUSTFLAGS`.

## sccache

Install with `winget install --id Mozilla.sccache --exact --scope user`.
The pool discovers it on PATH (including a newly updated user PATH), enables it
only for the lease, disables Rust incremental compilation for cache eligibility,
and defaults its cache limit to 10 GB. If missing, it warns and uses ordinary
compilation. Existing custom compiler wrappers are replaced only inside a lease.
Use `sccache --show-stats` to inspect effectiveness. The Cargo invocation helper
passes slot paths through CLI configuration during compilation; sccache 0.17
otherwise hashes slot-specific `CARGO_*` environment values and misses across slots. It does not eliminate local build outputs or cache final
executable linking; effectiveness depends on the compiler invocation and version.

Tune slots, compiler jobs and cache policy in `workspace/build-policy.json` while
builds are idle. Do not change capacity mid-session. Keep slot counts small to
bound disk usage. Do not make per-game/per-task target directories or clean the
pool while other builds are using it. Existing legacy targets have not been
deleted; remove them only during deliberate, idle maintenance.

## Verification

`scripts/test-cargo-pool.ps1` checks real concurrent allocation, bounded saturation,
same-project serialization, crash recovery and environment restoration. Run it
while other builds are idle. It uses real project identities and normal pool
state; it does not fabricate projects or modify their source.
