# Macroquad Toolkit Adoption Audit

Audit date: 2026-05-17

Scope: `H:\WebHatchery\RustGames`, including the root Cargo workspace plus adjacent game crates that have their own workspace files.

## Executive Summary

The current `macroquad-toolkit` already provides useful primitives for colors, input, buttons, panels, progress bars, camera movement, pathfinding, grid helpers, entity storage, notifications, data loading, persistence, sprites, textures, audio, and wasm storage. Most projects either use it lightly or have their own older/specialized versions of the same ideas.

The highest-value work is to upgrade `macroquad-toolkit` around patterns that have been reimplemented many times:

1. Rect-based, enabled/disabled, font-aware UI widgets.
2. UI layout helpers: virtual-resolution UI, scaling, `Rect`/`UiRect` utilities, scroll views, tooltips, modals, headers, footers, badges, meters, and text alignment.
3. Persistence: atomic writes, raw key save/load, version peeking, migrations, typed slot lists, app settings/profile bundles, configurable save roots, and test-path overrides.
4. Data/assets: manifest-relative loaders, wasm-safe embedded/native fallback, labeled multi-JSON loading, texture manifests, fallback textures, fonts, sounds, and batch loading.
5. Grid/pathfinding: flat grid storage, index helpers, closure-based walkability/cost, BFS, flood fill, reachability maps, reveal radius, and fog-state updates.
6. Camera: configurable drag button, zoom limits, bounds clamping, UI-capture awareness, and compatibility fields for existing wrappers.
7. Notification rendering: toolkit now has reusable toast rendering, but projects with specialized logs may still need adoption/config.
8. Immediate-mode friendly state/UI flow: helpers that allow screens to return UI intents/transitions without awkward split update/draw code.

## Implementation Progress

Updated on 2026-05-17.

Toolkit additions completed:

- UI helpers: font-aware measurement/centering, compact money formatting, and shared wrapping/truncation call sites.
- UI surface helpers: configurable rectangular `SurfaceStyle`, ragged surfaces, chamfered surfaces, and brush-stroke surfaces.
- Persistence helpers are now used for native atomic saves and save-version peeking in migrated games.
- Data/assets helpers are now used for labeled embedded JSON parsing, manifest-relative native asset paths, and texture manifest entries.
- Grid/pathfinding helpers are now used for flat-grid radius iteration, deterministic terrain RNG, BFS paths, and closure-based pathfinding call sites.
- Camera helpers now expose a macroquad camera adapter, optional cursor-centered wheel zoom, and a tested adoption path for bespoke 2D camera state.
- Notification rendering is now used by the dungeon projects and `ai_defense`.
- Persistence helpers now include a shared multi-file `SaveRoot`, default-on-missing bundle loading, and a timer-based autosave helper.
- Audio `SoundManager` now exposes `len`/`is_empty` and is wrapped by `scrapyard`.

Game adoption completed in this pass:

- `ai_defense`: resource bars and notification rendering now use toolkit UI/notification helpers.
- `ai_defense`: build/building panel surfaces now render through toolkit surface helpers.
- `ai_defense`: bespoke offset/zoom/middle-drag camera state now uses toolkit `Camera2D` with project-specific bounds, zoom limits, and drag button config.
- `alchemy_tower`: text wrapping/truncation, embedded JSON loading, save path, and atomic native saves now use toolkit helpers.
- `alchemy_tower`: panel frames, overlay subtitles, and overlay footer surfaces now render through toolkit surface helpers.
- `apartment`: centered text and progress bars now delegate to toolkit helpers.
- `apartment`: local mini/icon button surfaces now use toolkit button/surface rendering while preserving press-trigger behavior.
- `auction_game`: money formatting, virtual mouse lookup, centered/fitted text, and wrapping now use toolkit helpers while preserving its local font behavior.
- `auction_game`: dark/soft/highlight panels, badges, meters, and button surfaces now render through toolkit surface helpers.
- `cultivation`: progress bars and tooltips now delegate to toolkit drawing helpers.
- `cultivation`: panel surfaces and brush-stroke button backgrounds now use toolkit surface helpers.
- `dungeon_core`: locked/disabled button rows now use toolkit surface helpers.
- `dungeon_manager` and `dungeon_manager_2d`: notification toast rendering now uses toolkit rendering.
- `dungeon_manager` and `dungeon_manager_2d`: local save wrappers now use toolkit atomic native writes while preserving the existing save-file shape.
- `dungeon_manager` and `dungeon_manager_2d`: sidebar/drag tooltip surfaces now use toolkit surface helpers.
- `eclipse_heart`: rect hit-testing, wrapping, manifest-relative asset paths, and deck-builder wrapping now use toolkit helpers.
- `eclipse_heart`: multi-file profile/collection/deck/campaign/settings persistence now uses toolkit `SaveRoot` for default loading and atomic saves.
- `eclipse_heart`: panel and soft-panel surfaces now render through toolkit surface helpers.
- `finallanding`: local A* implementation now delegates to toolkit pathfinding.
- `finallanding`: top bar, side panel, and side-panel button surfaces now use toolkit surface helpers.
- `fracture`: minimap and supply-bar surfaces now use toolkit helpers.
- `frontier`: `ClickableRect` now delegates hover/click/press checks to toolkit input helpers.
- `kaiju_sim`: typography helpers now use toolkit text measurement, shadow text, and alignment helpers.
- `kaiju_sim`: save writes now use toolkit atomic JSON persistence while keeping the existing local save path.
- `kaiju_sim`: stat-bar surfaces now use toolkit surface helpers.
- `monstron`: labeled JSON parsing, centered text, button text, and virtual mouse conversion now use toolkit helpers.
- `monstron`: panel, button, and status surfaces now render through toolkit surface helpers.
- `nanite_swarm`: deterministic RNG, reveal-radius iteration, and drone BFS pathfinding now use toolkit helpers.
- `nanite_swarm`: panel and button surfaces now use toolkit surface helpers.
- `nft_adventurers/client`: texture manifest parsing/path fallback now uses toolkit `TextureConfig`.
- `nft_adventurers/client`: title/content/card surfaces in the main hold, detail, and inventory screens now route through toolkit surface helpers.
- `nightmare_shift`: wrapped/truncated text flow now uses toolkit text helpers.
- `nightmare_shift`: glass panel and glass button surfaces now use toolkit surface helpers.
- `quiteville`: text wrapping now delegates to toolkit.
- `quiteville`: tooltip surfaces now use toolkit tooltip rendering.
- `romcon`: notice surfaces now use toolkit surface helpers.
- `scrapyard`: sound manager now wraps toolkit `SoundManager`.
- `scrapyard`: main menu and upgrade-card surfaces now use toolkit surface helpers.
- `the_lewd_tower`: native atomic save and version peeking now use toolkit persistence helpers.
- `the_lewd_tower`: ragged panels, chamfered badges/metrics/cards/status/footer surfaces now use toolkit surface helpers.

Remaining higher-risk items:

- Full camera replacement remains project-by-project because current games differ in drag button, axis behavior, bounds, and public state expectations.
- Full UI-surface replacement remains intentionally partial where games have strong visual identity or custom font/theme plumbing.
- Persistence bundle migrations and wider autosave adoption remain good toolkit targets; the shared bundle root, autosave timer, slot discovery, atomic writes, path handling, and version peeking are now centralized.

## Workspace Notes

- `nanite_swarm` is in the root workspace and now uses `macroquad-toolkit` for deterministic RNG, reveal-radius iteration, and BFS pathfinding. It still has reusable persistence, UI, data-loading, and asset fallback patterns.
- `food_frenzy` is now a root workspace member. `dungeon_manager_2d` still has its own `Cargo.toml` and is excluded from the root workspace because it has the same package name as `dungeon_manager`.
- `nft_adventurers` is a workspace of its own. The client uses `macroquad-toolkit`; backend/shared crates should not pull in macroquad-specific rendering utilities.
- `dungeon_manager_2d` has the same package name as `dungeon_manager`, so adding it to the root workspace would require a rename or workspace restructuring.

## Toolkit Upgrade Backlog

### UI

Add:

- `button_rect`, `button_rect_styled`, `button_enabled`, and `button_rect_enabled`.
- Font-aware button/text APIs that accept `Option<&Font>` or a `TextStyle`.
- `RectExt`/`UiRect` helpers: `centered_x`, `centered_y`, `bottom`, `right`, `center`, `inset`, `contains_mouse`, `contains_point`.
- A `ButtonTone` or semantic style layer: primary, secondary, danger, warning, muted, selected, disabled.
- Virtual UI camera helpers: fixed logical resolution, `begin_virtual_ui_frame`, `virtual_mouse_position`, and scaling helpers.
- Tooltips: single-line, wrapped, max-width, max-lines, anchored positioning, and screen-edge clamping.
- Scroll helpers beyond `handle_scroll`: scroll regions, scrollbar drawing, clipped content callbacks, and list row hit testing.
- Modal/chrome helpers: overlay, centered panel, title/header/footer bars, action rows, status strips.
- Typography helpers: centered text, right-aligned text, shadow text, small caps, wrapped text with max-lines, fitted text, value rows.
- Reusable meters/stat bars, including animated bars.
- Badges/chips and compact number/money formatting.

Best source projects for this work:

- `auction_game`: virtual UI, `ButtonTone`, enabled `Rect` buttons, font-aware text, badges, meters, compact money formatting.
- `nightmare_shift`: `UiRect`, glass panels/buttons, stat blocks, max-lines wrapping, typography helpers.
- `the_lewd_tower`: UI scaling, modal chrome, footer/action bars, status strips, styled panel tiers.
- `cultivation`: tooltips, font-aware buttons, brush/surface style hooks.
- `monstron`: virtual resolution and virtual mouse helpers.

### Persistence

Add:

- Atomic native writes using temp file plus replace.
- Raw key/file JSON helpers for simple saves and settings.
- Version peeking without fully deserializing the target save type.
- Migration helpers: load versioned save, migrate stepwise, reject incompatible versions.
- Configurable app id, save directory, filename, and test override path.
- Typed slot ids and actual native slot discovery instead of only a hard-coded slot list.
- Bundle save/load for profile, settings, decks, campaigns, collection, etc.
- Optional metadata hooks such as saved-at timestamps and playtime/offline-progress updates.

Best source projects:

- `alchemy_tower`: atomic temp write/replace repository.
- `eclipse_heart`: multi-file persistence bundle with typed errors and tests.
- `the_lewd_tower`: raw-key save/load, settings persistence, version peeking.
- `cultivation`: versioned migration flow and wasm/native split.
- `food_frenzy`: configurable app path and test-path override.
- `kaiju_sim`: autosave manager pattern.

### Data And Assets

Add:

- `load_embedded_json_labeled` with better error context.
- `load_many_embedded_json` for common data packs.
- Manifest-relative native path fallback using `env!("CARGO_MANIFEST_DIR")`.
- Wasm-safe embedded/native fallback macro for JSON and asset paths.
- Texture manifest loading into `AssetManager`.
- Fallback/placeholder textures and filter configuration.
- Font loading and caching.
- Sound/music loading in the same style as texture loading.
- Optional cached remote asset download support for desktop-only clients.

Best source projects:

- `frontier`: wasm include/native fallback macro and texture path resolution.
- `eclipse_heart`: manifest-root data loader with typed/labeled errors and validation.
- `nft_adventurers`: texture manifest entries.
- `kaiju_sim`: local texture cache and remote asset cache.
- `nanite_swarm`: fallback icon/asset handling.

### Grid, Pathfinding, Camera, And Notifications

Add:

- Flat vector grid storage and `TilePos`/`GridPos` index conversion.
- Neighbor helpers, radius iteration, reveal-radius helpers, and terrain/range queries.
- BFS/unweighted shortest path, flood fill, reachability maps, and closure-based pathfinding.
- Fog/visibility update helpers that transition hidden/seen/visible states.
- Seeded RNG helper for deterministic terrain generation.
- Configurable `Camera2D`: drag button, min/max zoom, bounds clamp, speed, and public state accessors.
- Notification toast/log renderer, not only queue data.

Best source projects:

- `nanite_swarm`: flat grid, reveal radius, BFS, flood fill, deterministic terrain RNG.
- `dungeon_manager` and `dungeon_manager_2d`: fog/visibility updates and isometric camera compatibility.
- `ai_defense`: bounded camera with middle-mouse drag and zoom clamp.
- `quiteville`: wrapper-compatible `Camera2D` public state needs.

## Per-Game Report

### ai_defense

Current toolkit usage: colors and buttons are used in menu/UI paths.

Add or upgrade in toolkit from this game:

- Configurable 2D camera behavior: middle-mouse drag, min/max zoom, and map-bounds clamping.
- Embedded data-pack loading with clear default/fallback behavior.
- Notification rendering for simple timed messages. This has been added to toolkit and adopted in `ai_defense`.

Use more toolkit in game:

- Resource bars now use toolkit `progress_bar`.
- Move `save/mod.rs` toward toolkit persistence once versioned slot/raw-key helpers are strong enough.
- Notification drawing now uses toolkit rendering; queue/state can move later if the local gameplay API is simplified.
- Custom camera code now uses toolkit `Camera2D` with middle-mouse drag, zoom limits, and map bounds.

Priority: high for camera improvements, medium for save/data cleanup.

### alchemy_tower

Current toolkit usage: dark color palette and input click helpers.

Add or upgrade in toolkit from this game:

- Atomic persistence repository using temp write plus replace.
- Modal layout helpers: centered panels, footers, overlay/backdrop, inset rect helpers.
- Labeled multi-file embedded JSON loader.

Use more toolkit in game:

- Local wrapping/truncation now delegates to toolkit UI functions.
- Repeated embedded JSON parsing now uses toolkit labeled JSON loading.
- Native atomic save path now uses toolkit persistence helpers.
- Move generic panel/overlay helpers into toolkit and keep only game-specific tower styling local.

Priority: high for persistence upgrade, medium for text/layout consolidation.

### apartment

Current toolkit usage: UI wrappers, input, and persistence.

Add or upgrade in toolkit from this game:

- Enabled/disabled button API; toolkit has `ButtonStyle.disabled` but does not expose a first-class enabled button flow.
- Mini/icon button helpers.
- Centered text helpers that operate on a point or `Rect`. Point-centered text is now covered by toolkit.

Use more toolkit in game:

- City/career progress bars now use toolkit `progress_bar`.
- Thin `ui/common.rs` after toolkit gets enabled buttons and better `Rect` overloads.
- Convert data include/serde loaders to toolkit `data_loader` where practical.

Priority: medium.

### auction_game

Current toolkit usage: dependency exists, but direct toolkit usage is minimal or absent.

Add or upgrade in toolkit from this game:

- Virtual-resolution UI frame helpers (`1200x675` style), virtual mouse conversion, and font-aware measurement.
- `ButtonTone`, enabled `Rect` buttons, badges, meters, value rows, and compact money formatting.
- Thread-local/default UI font support or a cleaner explicit font style object.

Use more toolkit in game:

- Once toolkit has virtual UI and font-aware `Rect` widgets, replace the local UI module with toolkit-backed wrappers.
- Keep house art and game-specific card/list rendering local.

Priority: high as a source of reusable UI improvements.

### cultivation

Current toolkit usage: RNG and some data loading.

Add or upgrade in toolkit from this game:

- Tooltip renderer with wrapping and screen-edge handling. Basic tooltip rendering is now in toolkit and adopted here.
- Font-aware buttons and panels.
- Save migration helpers and raw native/wasm key storage.
- Font and texture asset managers.
- Optional style hooks for custom panel/button surfaces.

Use more toolkit in game:

- Progress bars and tooltip boxes now use toolkit helpers; generic buttons can move later after stronger `Rect`/font-aware APIs.
- Move save/load to toolkit after migration/raw-key helpers land.
- Use toolkit data loader consistently for game data.

Priority: high for persistence migration patterns, medium for UI.

### dungeon_core

Current toolkit usage: strong adoption of UI, RNG, and persistence.

Add or upgrade in toolkit from this game:

- Mostly no urgent extraction. This project is a good reference for current toolkit adoption.
- If repeated stat/resource panel patterns grow, extract stat rows or labeled resource meters.

Use more toolkit in game:

- Consider `progress_bar_labeled` where values are drawn next to bars manually.
- Use `data_loader` for any remaining include/serde data modules.

Priority: low.

### dungeon_manager

Current toolkit usage: dependency exists, but several local modules are older copies of toolkit ideas.

Add or upgrade in toolkit from this game:

- Fog/visibility update helpers for claimed/visible/seen tile transitions.
- Tooltip rendering for drag cost and multi-line hover help.
- Entity manager conveniences inspired by typed spawn helpers and `at_position` iteration.

Use more toolkit in game:

- Replace `draw_utils::draw_billboard` with `macroquad_toolkit::render3d::billboard::draw_billboard`.
- Replace local `engine/pathfinding.rs` with toolkit `pathfinding`.
- Replace local `state/wasm_storage.rs` with toolkit `wasm_storage`.
- Local native save writes now use toolkit atomic file replacement while preserving existing save files.
- Notification toast rendering now uses toolkit rendering; queue/state can move later where it reduces local logic.
- Replace local isometric camera state with toolkit `render3d::camera::IsometricCamera`.
- Alias toolkit `TilePos` and `FogState` where domain-specific tile state allows.

Priority: very high. This is one of the clearest cleanup targets.

### dungeon_manager_2d

Current toolkit usage: dependency exists, but the project repeats many `dungeon_manager` local toolkit clones.

Add or upgrade in toolkit from this game:

- Same as `dungeon_manager`: fog update helpers, tooltip rendering, typed entity conveniences, camera compatibility.

Use more toolkit in game:

- Replace local billboard/pathfinding/wasm-storage/camera clones with toolkit equivalents; notification toast rendering now uses toolkit rendering.
- Local native save writes now use toolkit atomic file replacement while preserving existing save files.
- Consider reconciling this project structurally with the root workspace, after resolving the duplicate package name.

Priority: very high, especially because it duplicates another game's duplicated code.

### eclipse_heart

Current toolkit usage: dependency exists, but direct usage is limited.

Add or upgrade in toolkit from this game:

- Multi-file persistence bundles with typed errors, defaults for missing files, and tests.
- Manifest-relative data loader with typed/labeled errors. Native asset path fallback is now using toolkit helpers.
- Max-lines wrapping and title/display text helpers.
- Rect input helpers and card/action-button primitives.

Use more toolkit in game:

- Replace generic panel and soft-panel code with toolkit wrappers once styling hooks improve.
- Rect hit-testing, wrapping, and manifest-relative path fallback now use toolkit helpers.
- Profile, collection, deck, campaign, and settings bundle persistence now uses toolkit `SaveRoot`; migration hooks can be layered on next.
- Keep deck import/export and card-specific art local.

Priority: high for persistence and data loading.

### finallanding

Current toolkit usage: colors and some UI helpers.

Add or upgrade in toolkit from this game:

- Immediate-mode state/screen pattern that can return intents or transitions from UI drawing.
- Basic layout helpers for top bar, side panel, game area, and selectable rows.

Use more toolkit in game:

- Replace manual side-panel buttons/rows with toolkit buttons after `Rect`/enabled APIs land.
- Use `GridLayout` or a new layout module for panel placement.
- Closure-based pathfinding now uses toolkit; keep simulation-specific state code local.

Priority: medium.

### food_frenzy

Current toolkit usage: root workspace member; uses toolkit wasm storage and previous migration work.

Add or upgrade in toolkit from this game:

- Configurable save root/app id/filename.
- Test save path override.
- Raw JSON save/load helpers that work the same on native and wasm.
- Active/disabled button states and simple bar widgets.

Use more toolkit in game:

- Replace local panel/button/bar helpers after toolkit gets enabled/active `Rect` buttons.
- Replace custom persistence with toolkit persistence after configurable paths and test override land.

Priority: medium.

### fracture

Current toolkit usage: good adoption of `Camera2D`, colors, panels, progress bars, and RNG.

Add or upgrade in toolkit from this game:

- Reusable commander/stat panel patterns if similar RTS panels appear in other projects.
- Minimap helper may be worth extracting later, but it is currently still game-specific.

Use more toolkit in game:

- Use `progress_bar_labeled` in places that manually pair labels with bars.
- Use future layout helpers for commander/build/victory panels.

Priority: low to medium.

### frontier

Current toolkit usage: UI/button wrappers and persistence.

Add or upgrade in toolkit from this game:

- `Rect` click/hover helpers or a `ClickableRect` equivalent. Basic `ClickableRect` delegation is now in place.
- Wasm include/native file fallback macros for JSON and asset paths.
- Texture manifest loading with path resolution fallback.

Use more toolkit in game:

- `ClickableRect` now delegates to toolkit input helpers.
- Move asset/data loading macros into toolkit and import them.
- Use `AssetManager` with a toolkit texture manifest loader.

Priority: medium.

### god_manager

Current toolkit usage: buttons and RNG in selected screens/engines.

Add or upgrade in toolkit from this game:

- No major unique extraction identified. It can benefit from common UI and state helpers once they exist.

Use more toolkit in game:

- Standardize screen UI on toolkit buttons/panels.
- Consider toolkit `NotificationManager` if event/message presentation expands.
- Toolkit `states::GameState` is optional; the existing enum state machine is acceptable.

Priority: low.

### kaiju_sim

Current toolkit usage: dependency exists, but local UI/assets/persistence still duplicate toolkit territory.

Add or upgrade in toolkit from this game:

- Animated stat bars with current/target state.
- Typography helpers: shadow text, centered text, right-aligned text, text measurement wrappers. These basic helpers are now in toolkit and adopted here.
- Autosave manager pattern.
- Asset manager support for directory loading, placeholder textures, filter mode, and desktop remote cache.

Use more toolkit in game:

- Replace local texture manager with toolkit `AssetManager` after placeholder/filter/directory support lands.
- Save writes now use toolkit atomic JSON persistence; broader version/autosave wrapping remains.
- Use toolkit progress bars/stat bars once animated bars are added.

Priority: medium.

### monstron

Current toolkit usage: persistence slots and data-oriented utilities are used; selected UI/text helpers now delegate to toolkit.

Add or upgrade in toolkit from this game:

- Virtual resolution camera and virtual mouse helpers.
- `Rect` enabled buttons.
- Labeled embedded JSON parsing. This now uses toolkit labeled JSON loading.

Use more toolkit in game:

- Replace local virtual UI utilities after toolkit supports logical resolution frames.
- Data `parse_json<T>(json, label)` now delegates to toolkit labeled embedded loading.
- Keep game-specific art/status drawing local.

Priority: high for virtual UI extraction.

### nanite_swarm

Current toolkit usage: now uses toolkit deterministic RNG, radius iteration, and BFS pathfinding. This remains a large adoption opportunity for persistence, UI, data loading, and assets.

Add or upgrade in toolkit from this game:

- Flat grid storage, `GridPos` index helpers, neighbor helpers, reveal-radius helper. Radius iteration is now in toolkit and adopted.
- BFS pathfinding, flood fill, reachability/power-grid traversal, and closure-based grid traversal. BFS is now in toolkit and adopted.
- Deterministic terrain RNG helper. This is now in toolkit and adopted.
- Data loader wrapper for labeled embedded JSON.
- Asset fallback/placeholder handling.
- Save hooks for metadata such as last-played timestamp/offline progress.

Use more toolkit in game:

- `macroquad-toolkit = { path = "../macroquad-toolkit" }` is now added.
- Replace `data/loader.rs` with `data_loader::load_embedded_json`.
- Replace generic UI panel/button/progress helpers with toolkit UI after `Rect`/enabled APIs land.
- Replace persistence with toolkit `JsonStorage`/slot helpers after metadata hooks and configurable paths land.
- Grid RNG, radius reveal, and BFS pathfinding now use toolkit helpers.

Priority: very high.

### nft_adventurers

Current toolkit usage: client uses toolkit heavily for assets, colors, UI buttons, and RNG. Backend/shared should avoid macroquad-rendering dependencies.

Add or upgrade in toolkit from this game:

- Texture manifest loading from `textures.json`. Basic texture config parsing/path fallback is now in toolkit and adopted by the client.
- Better card/list/panel primitives may reduce repeated screen UI code.

Use more toolkit in game:

- `client/src/data/assets.rs` now uses toolkit `TextureConfig` for manifest parsing/path fallback.
- Replace repeated draw-rectangle panels/cards with `section_panel`, `card`, or future styled panel helpers.
- Keep backend/shared utilities separate from macroquad-specific toolkit code.

Priority: medium.

### nightmare_shift

Current toolkit usage: heavy adoption of RNG, persistence, and UI buttons.

Add or upgrade in toolkit from this game:

- `UiRect` convenience type or `RectExt` trait.
- Glass panel/button style, max-lines wrapping, small caps, stat blocks, divider helpers, and text shadow helpers.
- Embedded texture cache helper for portrait/background assets.

Use more toolkit in game:

- After toolkit absorbs these UI primitives, replace the local generic parts of `ui/core.rs`.
- Keep game-specific background scenes and narrative portrait composition local.

Priority: high as a source of polished reusable UI primitives.

### quiteville

Current toolkit usage: wraps `Camera2D`, toolkit buttons/panels, and theme helpers.

Add or upgrade in toolkit from this game:

- Camera public-state compatibility or accessors for target/zoom/drag state.
- UI capture region helpers.
- Header/shadow text helper.

Use more toolkit in game:

- Local `ui/text_util::wrap_text` now delegates to toolkit `wrap_text`.
- Use toolkit data loader and `AssetManager` for embedded asset JSON and texture maps.
- Use toolkit persistence when save support is implemented.
- Shrink the camera wrapper once toolkit camera exposes the needed state/config.

Priority: medium.

### romcon

Current toolkit usage: strong adoption of prelude, assets, buttons, progress bars, RNG, and persistence slots.

Add or upgrade in toolkit from this game:

- Typed save slot ids and helper functions for version mismatch handling.
- Multi-load data helper for async JSON files with validation hooks.

Use more toolkit in game:

- Use `progress_bar_labeled` where hint meters or relationship meters duplicate label/bar composition.
- Keep story/deck validation local.

Priority: low to medium.

### scrapyard

Current toolkit usage: wraps toolkit asset/sprite types, and its local sound manager now wraps toolkit audio. Persistence and input are still mostly local.

Add or upgrade in toolkit from this game:

- Audio manager should support batch loading, enum maps, volume groups, and possibly music/SFX separation beyond the current minimal `SoundManager`.
- Configurable input snapshot/keymap helper.
- Profile/settings/save-slot persistence helpers.

Use more toolkit in game:

- Local sound manager now wraps toolkit `SoundManager`; batch/volume ergonomics can still improve.
- Replace manual JSON profile/settings/save files with toolkit persistence.
- Keep game-specific input actions local, but build them from a toolkit input snapshot if added.

Priority: medium.

### the_lewd_tower

Current toolkit usage: text block helpers, centered text, button styles, overlay, data loading, and wasm storage.

Add or upgrade in toolkit from this game:

- UI scaling helpers, scaled font sizes, scaled spacing.
- Modal/screen chrome helpers: tiered panels, utility bars, footer action rows, inline status strips.
- Raw key JSON save/load, save version peeking, compatible-save loading, and app settings persistence. Native version peeking now uses toolkit helpers.
- Custom button/panel surface hooks.

Use more toolkit in game:

- Keep stylized panel/button surfaces local until toolkit has style hooks.
- Native atomic save and version peeking now use toolkit persistence helpers; broader raw settings migration remains.
- Continue using toolkit `data_loader` for async data.

Priority: high for UI chrome and persistence version helpers.

## Recommended Work Order

1. Fix the clear local clones first: `dungeon_manager`, `dungeon_manager_2d`, and `nanite_swarm`.
2. Upgrade toolkit UI around `Rect`, enabled buttons, font-aware drawing, virtual UI, and tooltips using `auction_game`, `nightmare_shift`, `the_lewd_tower`, `cultivation`, and `monstron` as source material.
3. Upgrade persistence using `alchemy_tower`, `eclipse_heart`, `the_lewd_tower`, `cultivation`, `food_frenzy`, and `kaiju_sim`.
4. Upgrade data/assets with manifest-relative loading, labeled multi-loads, texture manifests, placeholders, fonts, and sounds.
5. Upgrade grid/pathfinding from `nanite_swarm` and fog/camera patterns from the dungeon projects and `ai_defense`.
6. Revisit each game and replace local wrappers with toolkit calls once the upgraded toolkit APIs are stable.
