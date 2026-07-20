# FTP Upload Asset-Pack Audit

This audit compares active Rust game projects under `D:\WebHatchery\RustGames` against the `asset_packs.json` publish flow. As of this pass, every active Cargo game project and the `template` project have asset-pack config.

## Current Asset-Pack Users

These active projects have `asset_packs.json`:

| Game | Packs | Source directories |
| --- | ---: | --- |
| `ai_defense` | 2 | `assets/tiles`, `assets/tiles_128` |
| `alchemy_tower` | 1 | `assets/generated` |
| `apartment` | 1 | `assets` |
| `auction_game` | 1 | `assets` |
| `cultivation` | 1 | `assets/generated` |
| `dungeon_core` | 1 | `assets` |
| `dungeon_manager` | 4 | `assets/tiles`, `assets/sprites`, `assets/icons`, `assets/ui` |
| `eclipse_heart` | 1 | `assets` |
| `finallanding` | 1 | `assets` |
| `food_frenzy` | 1 | `assets` |
| `frontier` | 1 | `assets` |
| `kaiju_sim` | 1 | `assets` |
| `monsterhall` | 1 | `assets` |
| `monstron` | 1 | `assets` |
| `nanite_swarm` | 1 | `assets` |
| `nightmare_shift` | 1 | `assets` |
| `ninja_village` | 1 | `assets` |
| `scrapyard` | 1 | `assets` |
| `the_enchanters_ledger` | 1 | `assets` |
| `the_lewd_tower` | 1 | `assets` |
| `toybox` | 1 | `assets` |

The `template` project also has `asset_packs.json` with one whole-directory `assets` pack. New games copied from the template will publish `assets.zip` by default, so new asset slices are covered without updating this audit.

Note: `ai_defense` has publish-time pack config, but this audit did not find a matching runtime `load_asset_pack`, `AssetPack`, `tiles.zip`, or `tiles_128.zip` reference in `ai_defense/src`. Verify the game still loads those packed assets correctly before using it as the only template for other games.

## Active Games Not Using Asset Packs

None for active Cargo game projects or `template`.

Archived projects with publish scripts and no asset packs:

| Game | Asset files | Asset size |
| --- | ---: | ---: |
| `archive/quiteville` | 27 | 2.62 MB |
| `archive/romcon` | 17 | 184.6 KB |
| `archive/fracture` | 15 | 102.2 KB |
| `archive/god_manager` | 0 | 0 B |
| `archive/nft_adventurers` | 0 | 0 B |

## Asset-Pack Coverage Implemented

- Added whole-directory `assets.zip` configs to `apartment`, `auction_game`, `dungeon_core`, `eclipse_heart`, `finallanding`, `food_frenzy`, `frontier`, `kaiju_sim`, `monsterhall`, `monstron`, `nanite_swarm`, `nightmare_shift`, `ninja_village`, `scrapyard`, `the_enchanters_ledger`, `the_lewd_tower`, `toybox`, and `template`.
- The new configs use `source: "assets"`, `output: "assets.zip"`, `entry_root: "assets"`, and `delete_source: true`. This keeps future files under `assets/` inside the pack automatically and removes the loose copied `assets/` tree from WebGL packages.
- Runtime zip-first loading was added where games currently request loose runtime files: texture loading in `apartment`, `dungeon_core`, `eclipse_heart`, `food_frenzy`, `frontier`, `kaiju_sim`, `nanite_swarm`, `ninja_village`, `scrapyard`, `the_enchanters_ledger`, `toybox`, and `template`; sound loading in `scrapyard`; and WASM JSON fallback fixes in `nanite_swarm`.
- Games whose active assets are compile-time embedded still get `assets.zip` so published loose assets do not grow silently. If those games later add runtime-loaded files, load the pack before requesting those files.
- `publish.ps1` now removes obsolete packed source folders from local preview deploys and FTP deploys when `delete_source: true`, so old loose `assets/` uploads do not linger after a project moves to `assets.zip`.

## Cross-Project Duplicate Uploads

Exact duplicate active-project assets found by SHA-256 total about 11.6 MB of repeated bytes. The largest duplicates are:

| Duplicate files | Projects | Repeated bytes |
| --- | --- | ---: |
| `assets/images/backdrops/chamber.png` | `monsterhall`, `the_lewd_tower` | 2.42 MB |
| `assets/images/backdrops/town.png` | `monsterhall`, `the_lewd_tower` | 2.22 MB |
| `assets/images/backdrops/town_overview.png` | `monsterhall`, `the_lewd_tower` | 2.11 MB |
| `assets/images/backdrops/expedition.png` | `monsterhall`, `the_lewd_tower` | 2.04 MB |
| `assets/images/backdrops/main_menu.png` | `monsterhall`, `the_lewd_tower` | 1.95 MB |
| `Rajdhani-SemiBold.ttf` | `finallanding`, `monsterhall`, `the_enchanters_ledger` | 762.4 KB |
| `assets/images/icons/ui_icon_atlas.png` | `monsterhall`, `the_lewd_tower` | 120.1 KB |

Best fix: add a shared game asset area, for example `/games/shared-assets/...`, and let projects reference shared files instead of carrying copies under each project directory. This is most valuable for `monsterhall` and `the_lewd_tower`.

## Other FTP Upload Reduction Opportunities

- `mq_js_bundle.js` is copied into every WebGL package. In the current `Release` tree it appears 19 times for about 681 KB total. Host it once under `/games/shared-assets/runtime/mq_js_bundle.js` or `/games/mq_js_bundle.js`, then keep per-game `index.html` references pointed at that shared URL.
- `shared.css` is already uploaded to `/games/shared.css`, but `publish.ps1` also copies it into every game package and rewrites `../shared.css` to `shared.css`. Stop uploading per-game copies for FTP deployments and keep the parent `../shared.css` reference.
- `sapp_jsutils.js` appears in projects with `storage.js` and is duplicated per game. Host it once beside `mq_js_bundle.js`.
- `publish-all-ftp.ps1` runs each game's publisher with `-ftp`; each game then uploads/checks the catalog. Add a batch mode that publishes games first and uploads the catalog once at the end.
- FTP skip logic avoids uploading identical files, but it checks identity by size and then downloads the remote file to compare bytes. A local/remote manifest with size plus hash would avoid repeated remote downloads during batch publishes.

Implemented follow-up:

- `publish.ps1` now prepares `Release/shared-assets/runtime` for `mq_js_bundle.js` and `sapp_jsutils.js`, plus `Release/shared-assets/fonts/Rajdhani-SemiBold.ttf`.
- Packaged game indexes now reference `../shared-assets/runtime/*.js` and `../shared.css`.
- Game FTP uploads now write/read `_ftp_manifest.json` with path, size, and SHA-256 entries before falling back to byte comparison.
- `publish-all-ftp.ps1` uploads shared assets once, publishes each game with shared/catalog FTP skipped, then uploads the catalog once.

## Implementation Notes

- Adding `asset_packs.json` is only half the change. Runtime code must load the zip through `macroquad_toolkit::assets::AssetManager::load_asset_pack` or `AssetPack::load` before the packed files are requested.
- For template-style projects, the default pack is now root-level `assets.zip` with entries rooted at `assets/...`.
- `macroquad-toolkit` supports zip-backed textures through `AssetManager` and zip-backed sounds through `macroquad_toolkit::audio::SoundManager`.
- For texture-heavy games, prefer packing cohesive directories that already map cleanly to runtime paths, such as `assets/generated`, `assets/textures`, `assets/images`, `assets/tiles`, or `assets/ui`.
- Keep `entry_root` equal to the original asset path so existing texture paths continue to work inside the zip.
- Use `delete_source: true` only after verifying the runtime code can load every affected asset from the pack.
