# Publishing and environment configuration

Every live game has a small `publish.ps1` wrapper. The shared implementation is
`rust_management/publish.ps1`; the workspace-root script is a forwarding
wrapper. Run the game-local wrapper from the game you intend to publish.

## Safety model

- No flag means a local **preview** deploy.
- `-Production` (or `-p`) selects the local production root.
- `-FTP` implies production and performs a remote upload.
- `-DryRun` suppresses deployment writes/uploads and tracking calls, but builds
  and packages still occur unless another option skips them.
- Batch scripts may build or upload every game. Only catalog maintainers should
  run them, and only intentionally.

Before any production/FTP action, run the same command with `-DryRun`, read the
reported game and destination, and verify the working tree/commit.

## Configuration lookup

The publisher first reads `D:\WebHatchery\.env`, then checks process/user/system
environment variables for missing values, then uses documented defaults. The
`.env` parser accepts simple `NAME=value` lines, blank lines, comments beginning
with `#`, and optionally quoted values.

Never commit the real `.env`. A redacted template is provided at
[webhatchery.env.example](webhatchery.env.example).

## Values

| Name | Required | Default | Purpose |
| --- | --- | --- | --- |
| `PREVIEW_ROOT` | No | `D:\xampp\htdocs` | Local preview deployment root; games go under `games/<slug>` |
| `PRODUCTION_ROOT` | No | `D:\WebHatcheryProduction` | Local production staging root |
| `FTP_SERVER` | FTP only | none | FTP hostname, without `ftp://` |
| `FTP_USERNAME` | FTP only | none | FTP account name |
| `FTP_PASSWORD` | FTP only | none | FTP account secret |
| `FTP_PORT` | No | `21` | FTP port |
| `FTP_REMOTE_ROOT` | No | `/` | Remote games/catalog root |
| `FTP_USE_SSL` | No | `false` | Enable FTPS for the .NET FTP request |
| `FTP_PASSIVE_MODE` | No | `true` | Use passive FTP |
| `PROJECT_ROOST_PUBLISH_TOKEN` | No | none | Records deploy/archive events; tracking is skipped without it |
| `PROJECT_ROOST_API_URL_PREVIEW` | No | `http://127.0.0.1/project_roost/api/v1` | Preview deployment tracker |
| `PROJECT_ROOST_API_URL_PRODUCTION` | No | `https://webhatchery.au/project_roost/api/v1` | Production deployment tracker |

Normal coding, building, testing, and preview packaging require no secrets.
Only `FTP_SERVER`, `FTP_USERNAME`, and `FTP_PASSWORD` are mandatory when `-FTP`
is used. Project Roost tracking is optional and non-fatal when unconfigured.

Capture variables such as `<PREFIX>_CAPTURE_PATH` and
`<PREFIX>_CAPTURE_SCENE` are temporary per-process test controls, not `.env`
deployment values. The prefix normally derives from the Cargo package; consult
the game's capture wrapper.

## Common commands

From a game directory:

```powershell
.\publish.ps1                         # Windows + WebGL; deploy preview
.\publish.ps1 -WebGLOnly              # WebGL only; deploy preview
.\publish.ps1 -WindowsOnly            # Windows only; still runs deploy phase
.\publish.ps1 -SkipBuild              # package existing native/WASM outputs
.\publish.ps1 -DeployOnly             # deploy existing dist/webgl
.\publish.ps1 -DryRun                 # build/package, show deployment only
.\publish.ps1 -Production -DryRun     # inspect production destination safely
.\publish.ps1 -Production             # local production staging
.\publish.ps1 -FTP -DryRun            # inspect remote production publish
.\publish.ps1 -FTP                    # build, stage, upload game/shared/catalog
```

`-SkipBuild` assumes required release binaries already exist. `-DeployOnly`
assumes `dist/webgl` already exists. A dry run is not a fast no-build check.

## What a normal publish does

1. Reads Cargo metadata to determine package, binary, and shared target paths.
2. Builds the native release unless WebGL/deploy-only was requested.
3. Packages the `.exe` and assets as `dist/<game>_windows.zip`.
4. Ensures the WASM target exists and builds the WebGL release unless excluded.
5. Generates `dist/webgl/index.html` from the shared web template and
   `game_page.json`.
6. Packages assets, browser runtime references, and catalog thumbnail.
7. Creates `dist/<game>_webgl.zip`.
8. Deploys browser files and the Windows download to
   `<deploy-root>/games/<game>`.
9. Refreshes shared runtime/catalog assets and optional Project Roost tracking.
10. With `-FTP`, uploads shared assets, the game, and the catalog using manifests
    to skip unchanged files and remove obsolete remote files.

The publisher may download/refresh `sapp_jsutils.js`; otherwise it uses the
Macroquad browser bundle resolved from Cargo's local registry so JavaScript and
WASM versions match.

## Batch commands

Run from `rust_management` or through the root wrappers only when explicitly
publishing the catalog:

```powershell
.\publish-all.ps1                    # preview-publish each game
.\publish-all-ftp.ps1 -DryRun        # rehearse full FTP catalog publish
.\publish-all-ftp.ps1                # publish all games/shared assets/catalog
.\build_all_webgl.ps1                # rebuild catalog artifacts in Release/
```

`publish-all-ftp.ps1` writes a timestamped transcript under
`RustGames/publish-logs/` and skips the catalog upload if any game fails.

## New game publishing checklist

- game folder is a sibling of `rust_management` and `macroquad-toolkit`;
- package/binary name in `Cargo.toml` is correct;
- game-local `publish.ps1` wrapper exists;
- `game_page.json` has the player-facing title and accurate page metadata;
- `catalog_thumbnail.png` exists at the game root;
- assets load on native and WASM builds;
- public repository URL is included only when the repository is actually public;
- capture/controls are touch-capable; and
- a preview publish passes before production or FTP is attempted.
