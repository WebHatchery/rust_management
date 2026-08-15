# Workstation and workspace setup

The supported local workflow is Windows and PowerShell. The exact versions on
the maintainer's working installation in August 2026 are Rust 1.96, Git 2.45,
Windows PowerShell 5.1, PowerShell 7.6, and Python 3.11. These are a known-good
baseline, not pinned minimum versions.

## 1. Install prerequisites

Required for normal game development:

- Git for Windows;
- Rust via `rustup`, using the stable MSVC toolchain;
- Visual Studio Build Tools with **Desktop development with C++**, or Visual
  Studio with the equivalent MSVC and Windows SDK components;
- PowerShell (Windows PowerShell 5.1 is present on supported Windows systems;
  PowerShell 7 is also suitable); and
- a GitHub account with access to the repositories.

Recommended:

- GitHub CLI (`gh`) for authentication and pull requests;
- Python 3 for repository maintenance scripts;
- VS Code with rust-analyzer, or another Rust-capable editor;
- a local web server such as XAMPP if you want the default preview URL.

Optional, role-specific tools:

- `wasm-opt` from Binaryen; currently used opportunistically for
  `nanite_swarm` only;
- an FTP-capable network route and credentials for live upload.

Install and update Rust, then add the browser build target:

```powershell
rustup default stable-msvc
rustup update
rustup target add wasm32-unknown-unknown
```

Verify the tools:

```powershell
git --version
rustc --version
cargo --version
rustup target list --installed
powershell -NoProfile -Command '$PSVersionTable.PSVersion'
```

`wasm32-unknown-unknown` and `x86_64-pc-windows-msvc` should appear in the
installed target/toolchain information.

## 2. Create the sibling repository layout

The directory may live anywhere for development. `D:\WebHatchery\RustGames` is
the maintainer's conventional location and is the least surprising choice for
publishing because the publisher also checks `D:\WebHatchery\.env`.

```powershell
New-Item -ItemType Directory -Path D:\WebHatchery\RustGames -Force
Set-Location D:\WebHatchery\RustGames
git clone https://github.com/Kalaith/rust_management.git
git clone https://github.com/Kalaith/macroquad-toolkit.git
git clone <assigned-game-repository-url> <game-folder-name>
```

Do not clone a game inside `rust_management`. Games, the toolkit, and management
must be siblings because games normally declare:

```toml
macroquad-toolkit = { path = "../macroquad-toolkit" }
```

Repository names are not always identical to folder names. Obtain the exact URL
from the maintainer or the existing game's `origin`; for example, some remotes
have a `_rust` suffix while their folder does not.

## 3. Restore workspace-root files

The `RustGames` root is not itself a Git repository. Its `Cargo.toml`,
`Cargo.lock`, `.cargo/config.toml`, and PowerShell forwarding scripts therefore
need to come from the maintainer or an approved workspace bootstrap bundle.
They are not recreated by cloning `rust_management`.

At minimum, confirm these exist:

```text
RustGames/Cargo.toml
RustGames/Cargo.lock
RustGames/.cargo/config.toml
RustGames/publish.ps1
```

The root `publish.ps1` forwards to `rust_management/publish.ps1`. The shared
`.cargo/config.toml` supplies WASM linker flags. Do not set `RUSTFLAGS` locally:
an environment value replaces those flags and causes broken or repeatedly
invalidated WASM builds.

If you only need to work in one standalone game checkout, Cargo can build it,
but the toolkit still must be at the expected sibling path and the standard
publisher requires the workspace/management layout.

## 4. Configure Git identity and authentication

```powershell
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
gh auth login
```

Use an email acceptable to the project's GitHub account settings. Confirm
access without changing anything:

```powershell
git -C .\rust_management fetch --dry-run origin
git -C .\macroquad-toolkit fetch --dry-run origin
git -C .\<game-folder> fetch --dry-run origin
```

## 5. Run the first smoke test

From the assigned game repository:

```powershell
Set-Location D:\WebHatchery\RustGames\<game-folder>
cargo fmt -- --check
cargo test
cargo clippy --all-targets --all-features -- -D warnings
cargo build
cargo build --release --target wasm32-unknown-unknown
```

Then run the game interactively:

```powershell
cargo run
```

Finally, verify publishing without uploading. `-DryRun` still performs builds
and packaging unless paired with an appropriate build flag:

```powershell
.\publish.ps1 -WebGLOnly -DryRun
```

If any baseline command fails before you make changes, save the complete output
and tell the maintainer. Do not hide a pre-existing failure inside your first
feature branch.

## 6. Editor exclusions

Index source folders, but exclude generated/heavy folders where your editor
supports it:

- `RustGames/target/`
- each game's `dist/`
- `RustGames/Release/`
- `RustGames/publish-logs/`

Never commit those generated outputs unless a specific repository already
tracks an artifact for an explicit reason.
