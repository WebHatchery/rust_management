# Troubleshooting

## Cargo cannot find `macroquad-toolkit`

Expected layout:

```text
RustGames/macroquad-toolkit/Cargo.toml
RustGames/<game>/Cargo.toml
```

The repositories must be siblings and the game dependency should resolve
`../macroquad-toolkit`. Do not copy toolkit source into the game.

## Native linking fails on Windows

Confirm the stable MSVC toolchain and Visual Studio C++ build tools/Windows SDK
are installed:

```powershell
rustup show
rustup default stable-msvc
cargo clean -p <game-package>
cargo build
```

Avoid deleting the entire shared `target/` as a first response; it discards the
cache for every game.

## WASM target or imports fail

```powershell
rustup target add wasm32-unknown-unknown
Remove-Item Env:RUSTFLAGS -ErrorAction SilentlyContinue
cargo build --release --target wasm32-unknown-unknown
```

The workspace `.cargo/config.toml` must contain the shared WASM linker flags.
An externally set `RUSTFLAGS` replaces, rather than extends, them.

## Publishing recompiles the world after manual WASM builds

Check for `RUSTFLAGS` in the process/user/system environment and remove it. Both
manual builds and publishing should use the same workspace config and shared
target directory.

## `publish.ps1` is not found or points to the wrong place

A game's wrapper expects `RustGames/publish.ps1`, which forwards to
`RustGames/rust_management/publish.ps1`. Confirm all three levels exist and
that the game is not nested inside `rust_management`.

## Preview deploy succeeds but the URL is unavailable

The default output is `\\wsl.localhost\Ubuntu\home\kalai\dev\games\<game>`. Publishing copies files;
it does not guarantee Apache/XAMPP is running. Start the configured web server,
or set `PREVIEW_ROOT` to a directory served by your local server. Browser games
should be served over HTTP rather than opened directly with `file://`.

## A WebGL page is missing or stale

- update `game_page.json`, not generated `dist/webgl/index.html`;
- delete/rebuild the game's `dist/webgl` through `publish.ps1`;
- confirm the WASM name matches the Cargo binary/page data;
- hard-refresh only after confirming the generated output is current; and
- change the shared shell in `rust_management/web/` if the behavior is truly
  catalog-wide.

## Assets work natively but are missing in WebGL

Paths are case-sensitive when hosted. Check exact filename case, the asset
registry (if present), embedded/runtime loading behavior, and the contents of
`dist/webgl/assets`. Run the asset-registry checks described in
[../asset-registry.md](../asset-registry.md).

## FTP publishing reports missing configuration

Only FTP mode requires `FTP_SERVER`, `FTP_USERNAME`, and `FTP_PASSWORD`. Put
authorized values in `D:\WebHatchery\.env` or environment variables and use a
dry run first. Check port, SSL, passive mode, firewall/VPN, and remote root with
the maintainer; never print the password while diagnosing.

## Project Roost tracking is skipped or warns

Tracking is optional. Without `PROJECT_ROOST_PUBLISH_TOKEN`, publishing states
that tracking was skipped. With a token, verify the appropriate API URL is
reachable. A tracker warning does not necessarily mean the build/deploy failed;
read the preceding publish output and final exit status.

## Documentation drift check fails

Do not repair a game-local shared file manually. Edit canonical content under
`rust_management/docs/`, then sync the affected projects:

```powershell
.\docs\sync-project-docs.ps1 -ProjectRoot <game-folder>
.\docs\check-project-docs.ps1 -ProjectRoot <game-folder>
```

## A Rust file exceeds 800 lines

Extract a cohesive responsibility into named child modules. Do not remove
spacing, compress expressions, or move a token function merely to pass the
count. Tests have the same 800-line limit.

## Before escalating a failure

Capture:

- repository and branch;
- `git status --short`;
- exact command and full error output;
- `rustc --version`, `cargo --version`, and `rustup show`;
- whether the failure existed before your change;
- target (`native` or `wasm32-unknown-unknown`); and
- relevant publish destination, with credentials redacted.

Prefer a copyable text log over a screenshot of terminal output.
