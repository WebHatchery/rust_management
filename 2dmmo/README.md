# Macroquad Toolkit Game Template

This is a working starter crate for new Rust + Macroquad games in this workspace.
It intentionally uses `macroquad-toolkit` heavily so new projects begin with the
same shared patterns as the existing games.

## Toolkit Features Already Wired

- `AssetManager` with a texture manifest at `assets/data/texture_manifest.json`
  and an exact runtime asset list in `asset_registry.json`
- `DataRegistry` and embedded JSON loading for data-driven actions
- `save_to_slot_with_version`, `load_from_slot_with_migration`, `delete_slot`, and `get_save_slots`
- `NotificationManager` with toolkit toast rendering
- `VirtualUi`, `SurfaceStyle`, `TextStyle`, `GridLayout`, meters, badges, tooltips, and text fitting
- `FlatGrid`, `FogState`, `TilePos`, line-of-sight visibility, and flood-fill reachability
- `Camera2D` with bounds, right-mouse drag, keyboard pan, and zoom limits
- `EventBus<UiAction>` so UI returns intents and game logic applies them
- Rust 2018 module layout using `data.rs`, `state.rs`, and `ui.rs` parent
  files instead of `mod.rs`

The template avoids browser-incompatible filesystem access. Static data is
embedded with `include_str!()`, runtime browser assets go through Macroquad or
toolkit async loaders, and save data uses macroquad-toolkit persistence.
Shared UI math, such as grid layout and mouse selection, is kept in helper
types so rendering and input do not duplicate coordinate calculations.

## Run

```powershell
cargo run --manifest-path template/Cargo.toml
```

## Test

```powershell
cargo test --manifest-path template/Cargo.toml
```

## Rename For A New Game

1. Copy `template/` to your new game folder.
2. Rename the package in `Cargo.toml`.
3. Change the `macroquad-toolkit` dependency path in `Cargo.toml` from
   `../../macroquad-toolkit` to `../macroquad-toolkit`. The former is correct
   only while the template remains nested inside `rust_management/`.
4. Update `assets/data/game_config.json`.
5. Replace `actions.json` with your game data.
6. Add externally loaded textures to both
   `assets/data/texture_manifest.json` and `asset_registry.json`. Keep embedded
   JSON data out of the registry. If the game adds other runtime-loaded assets,
   list each exact `assets/...` path in the registry as well.
7. Update `game_page.json` with the title, WASM/package name, page copy,
   controls, and `roost_slug` (`rust_<your_game_dir>`). The publisher generates
   `index.html` from this file and the shared web template; do not create a
   hand-maintained game `index.html`.
8. Add a root-level 16:9 `catalog_thumbnail.png` showing the title/menu screen.
9. Update the capture prefix/scenes in `scripts/capture_ui.ps1` if the package
   name and environment-variable prefix differ.
10. Run `cargo fmt`, `cargo test`, `cargo clippy --all-targets --all-features --
   -D warnings`, then `./publish.ps1` from the new game folder.

For the complete setup, Git, architecture, and publishing checklist, read the
management repository's `docs/onboarding/README.md`.
