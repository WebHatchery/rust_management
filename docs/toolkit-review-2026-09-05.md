# Games and Macroquad toolkit review — 5 September 2026

## Result and scope

**No game is wholly missing toolkit adoption. All 38 current top-level games and all five archived games declare and reference it in source. Both starter projects also use it.** The actionable list is therefore games with particular features still implemented locally, not games that need their first toolkit dependency.

This is a fresh static review of the files currently on disk: manifests, toolkit public modules, source-wide searches, and implementation reads for the findings below. It includes `dragons_den`, `mytherra`, and `tarrowyn` despite their exclusion from the root Cargo workspace, plus the five archives and two templates under `rust_management`. Nested client/server/core/protocol crates were inspected as parts of their games, not counted as extra games. Generated `target`, `Release`, `dist`, and vendored dependencies are not game-source findings.

This is a migration review, not a runtime correctness or visual certification. No games were changed, built, published, or played. Findings are confirmed examples, not a claim to have semantically audited every function. A missing import is not proof of duplication: grouped imports, preludes, aliases, and local adapters were checked where relevant. Domain models, server database code, save codecs, protocol decoding, tests, and game-specific presentation are not automatically toolkit candidates.

## Toolkit features available now

The source is the authority; the short README is not a complete catalogue.

| Area | Existing capabilities | Source |
| --- | --- | --- |
| UI and text | Shared/custom fonts; measured wrapping, fitting and truncation; buttons, cards, panels, forms, scrolling, tabs, number formatting, delayed tooltips. | [macroquad-toolkit/src/ui.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/ui.rs:1) |
| Layout and interaction | VirtualUi and DPI-aware viewports; Pointer and target sizing; overlap/occlusion auditing; input snapshots, hit targets, gamepads, touch tap/pan/pinch recognition. | [macroquad-toolkit/src/input.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/input.rs:1) |
| UI verification | Bounds/collision audits, contrast checks, pseudo-localization, target audits, headless capture and filmstrips. | [macroquad-toolkit/src/capture.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/capture.rs:1) |
| Content and assets | Labeled JSON parsers; embedded/runtime/fallback loading; data registries; asset packs, texture cache/manifests, shared artwork/icons. | [macroquad-toolkit/src/data_loader.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/data_loader.rs:1) |
| Persistence | Atomic native writes; qualified browser keys; configured paths; SaveRoot; slots, version inspection/migration callbacks, single backup/restore/quarantine, autosave. | [macroquad-toolkit/src/persistence.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/persistence.rs:1) |
| Rendering and space | 2D pan/zoom; 3D cameras, picking, billboards; sprites/variation; grids, isometric coordinates, fog/vision, pathfinding/cache. | [macroquad-toolkit/src/lib.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/lib.rs:1) |
| Simulation helpers | Seeded RNG and state restoration; deterministic value noise; math/easing; timers and timelines; entities, event bus, states. | [macroquad-toolkit/src/rng.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/rng.rs:1) |
| Effects and feedback | Particles, screen shake/fade, floating text, projectiles, CRT and typewriter effects; notifications, settings, achievement registry, debug overlay and crash handling. | [macroquad-toolkit/src/fx.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/fx.rs:1) |
| Procedural art and sound | CPU raster utilities; Painter/Buffer with image comparisons; SoundManager; deterministic synth voices, PCM-to-WAV encoding, musical score/loop helpers and audio audits. | [macroquad-toolkit/src/synth.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/synth.rs:1) |
| Recent specialized helpers | Countup/Stepper outcome reveals; strip/spinner animation; bounded min/max time series. These need matching game behavior before adoption is useful. | [macroquad-toolkit/src/reveal.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/reveal.rs:1) |
| Optional services | `net`: frame-polled native/WASM JSON HTTP and bearer headers; `analytics`: anonymous batched telemetry (implies net); `db`: SQLite helpers. Default feature set is empty. | [macroquad-toolkit/Cargo.toml](D:/WebHatchery/RustGames/macroquad-toolkit/Cargo.toml:1) |

## List 1 — games bypassing an available toolkit feature

These rows identify actual local implementations. They do not mean the entire game, or even the entire feature, lacks toolkit use. **High** priority means a relatively contained migration with broad consistency benefits; **medium** means behavior or compatibility needs closer attention.

### A. JSON content loading — high priority

Use `parse_json_labeled`, `load_embedded_json_labeled`, `load_json_file[_sync]`, or `load_json_with_fallback_sync`, depending on the current loading contract. The toolkit's `include_json_str!` only embeds text; following it with a local `serde_json::from_str` still bypasses shared parsing/diagnostics.

| Game | Confirmed local work | Evidence |
| --- | --- | --- |
| apartment | Platform branches, filesystem fallback and parsing in a generic loader macro; further direct parsing in content modules. | [apartment/src/util/loader.rs](D:/WebHatchery/RustGames/apartment/src/util/loader.rs:10) |
| auction_game | Embedded game-data parsing directly through serde. | [auction_game/src/data/mod.rs](D:/WebHatchery/RustGames/auction_game/src/data/mod.rs:14) |
| cultivation | Repeated direct parsing across the content catalogue, despite partial toolkit use elsewhere in the loader. | [cultivation/src/data/loader.rs](D:/WebHatchery/RustGames/cultivation/src/data/loader.rs:88) |
| dragons_hoard | Achievement/hint content still parsed locally; the achievement gameplay rules should stay local. | [dragons_hoard/src/state/achievements.rs](D:/WebHatchery/RustGames/dragons_hoard/src/state/achievements.rs:159) |
| dungeon_manager | Repeated typed content loaders, including traps/traits/tiles/technologies/rooms. | [dungeon_manager/src/data/traps.rs](D:/WebHatchery/RustGames/dungeon_manager/src/data/traps.rs:44) |
| eclipse_heart | Native generic loader reads and parses directly; its WASM branch already uses load_json_file. | [eclipse_heart/src/data/loader.rs](D:/WebHatchery/RustGames/eclipse_heart/src/data/loader.rs:156) |
| feast_frenzy | Generic parse-or-fallback chain repeats runtime/embedded/default handling. Its runtime helper always constructs assets/data/game_data.json; verify the intended override path for each content type. | [feast_frenzy/src/data.rs](D:/WebHatchery/RustGames/feast_frenzy/src/data.rs:574) |
| frontier | Project-local platform-aware JSON macro. | [frontier/src/data/mod.rs](D:/WebHatchery/RustGames/frontier/src/data/mod.rs:20) |
| kaiju_sim | Traits, balance and tournaments parsed directly from embedded JSON. | [kaiju_sim/src/data/loader.rs](D:/WebHatchery/RustGames/kaiju_sim/src/data/loader.rs:195) |
| last_assembly | UI strings parse both embedded and runtime text locally. | [last_assembly/src/data/strings.rs](D:/WebHatchery/RustGames/last_assembly/src/data/strings.rs:32) |
| nightmare_shift | Repeated per-content direct parsers in the data loader. | [nightmare_shift/src/data/loader.rs](D:/WebHatchery/RustGames/nightmare_shift/src/data/loader.rs:78) |
| scrapyard | Contract definition parsing bypasses the labeled parser. | [scrapyard/src/data/contracts.rs](D:/WebHatchery/RustGames/scrapyard/src/data/contracts.rs:32) |
| the_enchanters_ledger | Rune template content parsing is local. | [the_enchanters_ledger/src/rune_drawing/templates.rs](D:/WebHatchery/RustGames/the_enchanters_ledger/src/rune_drawing/templates.rs:36) |
| fracture (archived) | Local platform-loading macro followed by repeated content parsers. | [rust_management/archive/fracture/src/data.rs](D:/WebHatchery/RustGames/rust_management/archive/fracture/src/data.rs:299) |
| quiteville (archived) | Direct config and zone parsing. | [rust_management/archive/quiteville/src/assets.rs](D:/WebHatchery/RustGames/rust_management/archive/quiteville/src/assets.rs:16) |
| romcon (archived) | Repeated async load_string plus serde parsing; validation can remain game-owned. | [rust_management/archive/romcon/src/data/loader.rs](D:/WebHatchery/RustGames/rust_management/archive/romcon/src/data/loader.rs:15) |

**Compatibility detail:** the current toolkit fallback loader returns an error when an existing runtime file is unreadable or invalid; it falls back when no candidate exists. Several local loaders instead swallow read or parse errors. Preserve the intended policy explicitly, and extend the shared API if a reusable lenient policy is required. Keep typed schemas, lookup construction and semantic validation in each game. Do not indiscriminately replace protocol/save deserialization.

### B. Text layout — high priority

| Game | Duplicated or less capable local behavior | Evidence |
| --- | --- | --- |
| feast_frenzy | Three measured word-wrap loops: tutorial_panel, specialization and prestige_modal. | [feast_frenzy/src/ui/tutorial_panel.rs](D:/WebHatchery/RustGames/feast_frenzy/src/ui/tutorial_panel.rs:93) |
| nanite_swarm | Measured word wrapping in the directive panel. | [nanite_swarm/src/screens/planetary_view/hud/directive_panel.rs](D:/WebHatchery/RustGames/nanite_swarm/src/screens/planetary_view/hud/directive_panel.rs:250) |
| frontier | Character-count word wrapping for tooltips. | [frontier/src/ui/mod.rs](D:/WebHatchery/RustGames/frontier/src/ui/mod.rs:125) |
| eclipse_heart | Campaign hub wraps by character count, although card widgets already use toolkit wrapping. | [eclipse_heart/src/screens/campaign_hub.rs](D:/WebHatchery/RustGames/eclipse_heart/src/screens/campaign_hub.rs:478) |
| hatchspire | Help chunks text by character count; tower status has another local wrapping loop. | [hatchspire/src/screens/help.rs](D:/WebHatchery/RustGames/hatchspire/src/screens/help.rs:93) |
| idle_hands | Mobile tutorial wrapping estimates width using byte lengths. | [idle_hands/src/mobile_tutorial_ui.rs](D:/WebHatchery/RustGames/idle_hands/src/mobile_tutorial_ui.rs:123) |
| mirexis | The same byte-count wrapping loop appears in outsider_ui and colony_ui. | [mirexis/src/outsider_ui.rs](D:/WebHatchery/RustGames/mirexis/src/outsider_ui.rs:136) |
| finallanding | Character truncation feeds tooltip rendering rather than a measured width budget. | [finallanding/src/ui/tooltip.rs](D:/WebHatchery/RustGames/finallanding/src/ui/tooltip.rs:15) |
| tb_realms | UI truncation uses character counts; use measured width for rendered labels. | [tb_realms/src/ui/widgets.rs](D:/WebHatchery/RustGames/tb_realms/src/ui/widgets.rs:88) |
Use toolkit `wrap_text[_ex]`, `truncate_text_to_width[_ex]`, `fit_text_to_box`, and `draw_text_block` with the actual font and rectangle budget. This is a pixel-layout migration, not a promise of identical line breaks. Preserve line limits, intentional newlines, ellipsis and touch-layout readability. Evidence for the shared implementations: [macroquad-toolkit/src/ui/font/text.rs](D:/WebHatchery/RustGames/macroquad-toolkit/src/ui/font/text.rs:93).

### C. Other available features — medium priority

| Game | Migration | Qualification | Evidence |
| --- | --- | --- | --- |
| stellar_legacy | Replace hand-written RIFF/WAV header encoding with `synth::wav_bytes`; consider `SoundManager` for reusable playback bookkeeping. | Keep its sample function and envelope initially. This can preserve the current PCM exactly; translating cues to synth voices is a separate audible change. | [stellar_legacy/src/audio.rs](D:/WebHatchery/RustGames/stellar_legacy/src/audio.rs:128) |
| last_assembly | Use `fx::ParticleSystem` for local particle storage, integration and expiry. | Match its per-frame drag and local rendering; keep death-emission tuning local. Existing notification use does not imply effects adoption. | [last_assembly/src/state/gameplay/helpers.rs](D:/WebHatchery/RustGames/last_assembly/src/state/gameplay/helpers.rs:248) |
| planet_trader | Share the xorshift primitive with `rng::SeededRng`. | VisualRng uses the same xorshift shifts/multiplier but different seed mixing and low-bit float conversion. A compatibility adapter using from_state/next_u64 is required to retain planet appearances; define zero-state behavior. | [planet_trader/src/ui/planet_graphics.rs](D:/WebHatchery/RustGames/planet_trader/src/ui/planet_graphics.rs:50) |
| finallanding | Use shared RNG facilities for new simulation streams. | Current SimulationRng is an LCG, not the toolkit xorshift. Existing seeded scenarios will change under a direct replacement; see C4 below. | [finallanding/src/data/simulation_rng.rs](D:/WebHatchery/RustGames/finallanding/src/data/simulation_rng.rs:2) |
| hatchspire | Use shared RNG facilities for new map-generation streams. | TowerMapRng is another LCG with a different increment. Preserve existing map seeds through a versioned generator or compatibility implementation. | [hatchspire/src/state/tower/map.rs](D:/WebHatchery/RustGames/hatchspire/src/state/tower/map.rs:322) |
| nft_adventurers (archived client) | Use optional `net::HttpClient` / `Pending` for ordinary JSON HTTP. | The client owns repeated synchronous ureq calls. Requires enabling net and restructuring pending UI states; retain wallet signing and authentication semantics locally. | [rust_management/archive/nft_adventurers/client/src/api/mod.rs](D:/WebHatchery/RustGames/rust_management/archive/nft_adventurers/client/src/api/mod.rs:209) |

## List 2 — duplicated game infrastructure worth adding to the toolkit

These are **extensions to existing modules**, not reasons to create a second parallel toolkit system. Each has at least two concrete consumers. The API names below are proposals, not existing exports.

| ID | Shared candidate | Games and evidence | Existing support and missing part | Suggested boundary |
| --- | --- | --- | --- | --- |
| C1 | Configurable multi-generation backup rotation and recovery | [carriage_run/src/game/persistence.rs](D:/WebHatchery/RustGames/carriage_run/src/game/persistence.rs:55)<br>[nanite_swarm/src/state/persistence.rs](D:/WebHatchery/RustGames/nanite_swarm/src/state/persistence.rs:181)<br>[monsterhall/src/state/persistence.rs](D:/WebHatchery/RustGames/monsterhall/src/state/persistence.rs:256) | Slots already offer one backup/restore/quarantine. Games still implement three-generation rotation, recovery selection or valid-copy protection themselves. | A storage-backend abstraction plus retention count, raw-copy rotation, validation callback and structured recovery result. Preserve old envelopes/versions; never relabel an old backup as current schema without migration. Keep game migrations and player messages local. Test failed writes and corrupt/future-version primaries. |
| C2 | Explicit legacy-key import for qualified browser storage | [feast_frenzy/src/persistence.rs](D:/WebHatchery/RustGames/feast_frenzy/src/persistence.rs:116)<br>[monsterhall/src/state/persistence.rs](D:/WebHatchery/RustGames/monsterhall/src/state/persistence.rs:180) | Toolkit slots recognize their own legacy save_<slot> convention, but these games import arbitrary historical raw keys into qualified JSON keys. | A caller-supplied allowlist of old keys, validation before copy, explicit migration status and preservation of the old value until a successful write. Do not guess legacy keys globally or change existing primary-key precedence. |
| C3 | Viewport-aware, input-independent 2D camera transform | [nanite_swarm/src/state/camera.rs](D:/WebHatchery/RustGames/nanite_swarm/src/state/camera.rs:21)<br>[mirexis/src/grid_ui.rs](D:/WebHatchery/RustGames/mirexis/src/grid_ui.rs:30) | Camera2D already supports pan/zoom/cursor focus, and TouchGesture recognizes gestures. Games still maintain viewport-relative transforms, cursor-pinned zoom and interaction state around game panels. | Extract pure screen/world transforms and zoom-at-anchor with explicit viewport and bounds policy. Compose the existing gesture recognizer. Keep isometric projection, tracked units, colony confirmation and saved game schemas local. This is not a drop-in full camera replacement. |
| C4 | Compatibility RNG primitives for existing LCG streams | [finallanding/src/data/simulation_rng.rs](D:/WebHatchery/RustGames/finallanding/src/data/simulation_rng.rs:28)<br>[hatchspire/src/state/tower/map.rs](D:/WebHatchery/RustGames/hatchspire/src/state/tower/map.rs:331) | SeededRng exists, but it cannot reproduce either LCG stream. The two local generators share multiply/add/shift structure with different increments and range contracts. | Only add a small parameterized or named legacy generator if both games are migrated. Lock down byte-for-byte seed sequences, zero seeds and interval endpoints first. Prefer SeededRng for new code; do not unify old streams by silently changing their algorithms. |

## Already migrated or intentionally local

These were checked to avoid stale findings from earlier game versions:

- Alchemy Tower text helpers already delegate to toolkit wrapping/truncation. [alchemy_tower/src/ui/text.rs](D:/WebHatchery/RustGames/alchemy_tower/src/ui/text.rs:4)
- Last Assembly bounded-text truncation already delegates to the toolkit. [last_assembly/src/ui/text.rs](D:/WebHatchery/RustGames/last_assembly/src/ui/text.rs:13)
- Auction Game money formatting already delegates; its themed button rendering is not by itself a missing toolkit feature. [auction_game/src/ui/mod.rs](D:/WebHatchery/RustGames/auction_game/src/ui/mod.rs:65)
- Nightmare Shift weather uses toolkit ParticleSystem, ScreenFade and ScreenShake; its weather emission recipes are appropriately local. [nightmare_shift/src/engine/effects.rs](D:/WebHatchery/RustGames/nightmare_shift/src/engine/effects.rs:14)
- Eclipse Heart card wrapping delegates to shared wrap_text; the separate campaign-hub loop is the remaining finding. [eclipse_heart/src/ui/card_widgets.rs](D:/WebHatchery/RustGames/eclipse_heart/src/ui/card_widgets.rs:452)
- Quiteville wrapping is already a toolkit adapter. [rust_management/archive/quiteville/src/ui/text_util.rs](D:/WebHatchery/RustGames/rust_management/archive/quiteville/src/ui/text_util.rs:2)
- Hatchspire uses grouped capture/crash imports and the shared capture runner. Simple namespace searches can miss this. [hatchspire/src/main.rs](D:/WebHatchery/RustGames/hatchspire/src/main.rs:4)
- Nightmare Shift browser quarantine already uses quarantine_slot; native quarantine targets its historical custom path, so it is not a direct slot-API substitution. [nightmare_shift/src/state/persistence.rs](D:/WebHatchery/RustGames/nightmare_shift/src/state/persistence.rs:97)

Keep game achievement conditions, economies, combat, procedural art compositions, authored music, save schema migrations and typed state transitions game-owned. Different UI skins are not duplicates just because they draw rectangles. Server SQL repositories are not missing toolkit `db` adoption. Absence of analytics is not a duplication finding: only `idle_hands` currently opts into that feature, and wider adoption is a product decision. Likewise, specialized `strip`, `reveal`, `score`, and `series` helpers are not mandatory for games without matching behavior.

## Complete project inventory

Every row below has a toolkit dependency and at least one direct source reference. The modules shown are a compact **positive-use sample**, not a complete import resolver or an unused-feature score. Nested game crates are grouped under their owning game; modules referenced only by a nested crate may appear. A dash in the finding column means no confirmed migration from this review's selected findings, not proof that the game contains no duplication.

| Game/project | Classification | Existing toolkit source evidence | Findings |
| --- | --- | --- | --- |
| alchemy_tower | Current game | [assets, audio, capture, colors, data_loader, fx, input, …](D:/WebHatchery/RustGames/alchemy_tower/src/art/asset_manifest.rs:10) | — |
| apartment | Current game | [assets, capture, fx, input, math, persistence, rng, …](D:/WebHatchery/RustGames/apartment/src/assets.rs:2) | JSON |
| auction_game | Current game | [capture, persistence, rng, ui](D:/WebHatchery/RustGames/auction_game/src/data/mod.rs:14) | JSON |
| biofoundry | Current game | [audio, camera, capture, data_loader, events, grid, input, …](D:/WebHatchery/RustGames/biofoundry/src/audio.rs:6) | — |
| carriage_run | Current game | [assets, audio, capture, data_loader, events, fx, input, …](D:/WebHatchery/RustGames/carriage_run/src/audio.rs:7) | C1 |
| cultivation | Current game | [assets, capture, colors, data_loader, persistence, rng, timing, …](D:/WebHatchery/RustGames/cultivation/src/data/loader.rs:319) | JSON |
| daemon_directorate | Current game | [capture, colors, data_loader, debug, events, notifications, persistence, …](D:/WebHatchery/RustGames/daemon_directorate/src/data.rs:19) | — |
| dragons_den | Current game | [achievements, capture, colors, data_loader, events, fx, notifications, …](D:/WebHatchery/RustGames/dragons_den/src/data.rs:12) | — |
| dragons_hoard | Current game | [achievements, assets, capture, data_loader, events, fx, math, …](D:/WebHatchery/RustGames/dragons_hoard/src/audio.rs:8) | JSON |
| dungeon_core | Current game | [assets, capture, colors, crash, data_loader, input, persistence, …](D:/WebHatchery/RustGames/dungeon_core/src/app_support.rs:5) | — |
| dungeon_manager | Current game | [assets, capture, fx, grid, notifications, pathfinding, persistence, …](D:/WebHatchery/RustGames/dungeon_manager/src/bin/balance_calculator/data.rs:167) | JSON |
| eclipse_heart | Current game | [assets, capture, colors, data_loader, input, persistence, rng, …](D:/WebHatchery/RustGames/eclipse_heart/src/data/loader.rs:171) | JSON, Text |
| feast_frenzy | Current game | [assets, audio, capture, colors, math, persistence, rng, …](D:/WebHatchery/RustGames/feast_frenzy/src/app.rs:21) | C2, JSON, Text |
| finallanding | Current game | [capture, colors, debug, input, pathfinding, raster, ui](D:/WebHatchery/RustGames/finallanding/src/data/grid.rs:1) | C4, Other features, Text |
| frontier | Current game | [assets, capture, input, persistence, rng, ui](D:/WebHatchery/RustGames/frontier/src/combat/unit.rs:288) | JSON, Text |
| hatchspire | Current game | [audio, data_loader, input, persistence, synth, ui](D:/WebHatchery/RustGames/hatchspire/src/audio.rs:4) | C4, Other features, Text |
| idle_hands | Current game | [analytics, assets, capture, data_loader, notifications, persistence, rng, …](D:/WebHatchery/RustGames/idle_hands/src/analytics.rs:7) | Text |
| iron_fauna | Current game | [assets, audio, capture, colors, data_loader, notifications, persistence, …](D:/WebHatchery/RustGames/iron_fauna/src/audio.rs:6) | — |
| kaiju_sim | Current game | [assets, capture, colors, fx, math, persistence, rng, …](D:/WebHatchery/RustGames/kaiju_sim/src/data/kaiju.rs:192) | JSON |
| last_assembly | Current game | [camera, capture, colors, data_loader, math, notifications, persistence, …](D:/WebHatchery/RustGames/last_assembly/src/data/loader.rs:12) | JSON, Other features |
| master_thief | Current game | [achievements, capture, data_loader, events, fx, notifications, paint, …](D:/WebHatchery/RustGames/master_thief/src/audio.rs:9) | — |
| mirexis | Current game | [assets, audio, capture, data_loader, events, grid, notifications, …](D:/WebHatchery/RustGames/mirexis/src/action_preview.rs:5) | C3, Text |
| monsterhall | Current game | [capture, colors, data_loader, math, persistence, rng, ui, …](D:/WebHatchery/RustGames/monsterhall/src/data/loader.rs:5) | C1, C2 |
| mytherra | Current game | [achievements, capture, data_loader, events, math, net, notifications, …](D:/WebHatchery/RustGames/mytherra/mytherra-core/src/data.rs:61) | — |
| nanite_swarm | Current game | [achievements, assets, audio, capture, colors, data_loader, debug, …](D:/WebHatchery/RustGames/nanite_swarm/src/assets.rs:5) | C1, C3, Text |
| nightmare_shift | Current game | [achievements, assets, audio, capture, colors, crash, fx, …](D:/WebHatchery/RustGames/nightmare_shift/src/audio.rs:10) | JSON |
| occupational_hazard | Current game | [capture, data_loader, ui](D:/WebHatchery/RustGames/occupational_hazard/src/contracts.rs:29) | — |
| planet_trader | Current game | [capture, data_loader, events, notifications, persistence, settings, ui](D:/WebHatchery/RustGames/planet_trader/src/data.rs:3) | Other features |
| planetfall_engineer | Current game | [assets, capture, data_loader, persistence, render3d, ui](D:/WebHatchery/RustGames/planetfall_engineer/src/content.rs:7) | — |
| realmseed | Current game | [assets, camera, capture, data_loader, events, notifications, persistence, …](D:/WebHatchery/RustGames/realmseed/src/data.rs:15) | — |
| 2dmmo | Starter | [assets, camera, capture, data_loader, events, grid, notifications, …](D:/WebHatchery/RustGames/rust_management/2dmmo/src/data.rs:3) | — |
| fracture | Archived | [camera, colors, rng, ui](D:/WebHatchery/RustGames/rust_management/archive/fracture/src/ai/commander_ai.rs:65) | JSON |
| god_manager | Archived | [rng, ui](D:/WebHatchery/RustGames/rust_management/archive/god_manager/src/engine/combat.rs:3) | — |
| nft_adventurers | Archived | [assets, colors, rng, ui](D:/WebHatchery/RustGames/rust_management/archive/nft_adventurers/backend/src/engine/feat_generator.rs:26) | Other features |
| quiteville | Archived | [camera, rng, ui](D:/WebHatchery/RustGames/rust_management/archive/quiteville/src/assets.rs:6) | JSON |
| romcon | Archived | [assets, persistence, ui](D:/WebHatchery/RustGames/rust_management/archive/romcon/src/game.rs:10) | JSON |
| template | Starter | [assets, camera, capture, data_loader, events, grid, notifications, …](D:/WebHatchery/RustGames/rust_management/template/src/data.rs:3) | — |
| scrapyard | Current game | [assets, audio, capture, colors, debug, events, fx, …](D:/WebHatchery/RustGames/scrapyard/src/data/contracts.rs:3) | JSON |
| sentience | Current game | [assets, capture, data_loader, events, notifications, persistence, timing, …](D:/WebHatchery/RustGames/sentience/src/data.rs:3) | — |
| stellar_legacy | Current game | [achievements, assets, capture, crash, data_loader, events, fx, …](D:/WebHatchery/RustGames/stellar_legacy/src/achievements.rs:6) | Other features |
| tarrowyn | Current game | [assets, camera, capture, data_loader, events, grid, net, …](D:/WebHatchery/RustGames/tarrowyn/server/src/content.rs:3) | — |
| tb_realms | Current game | [achievements, capture, data_loader, events, net, notifications, persistence, …](D:/WebHatchery/RustGames/tb_realms/src/data.rs:6) | Text |
| the_enchanters_ledger | Current game | [assets, capture, data_loader, events, notifications, persistence, settings, …](D:/WebHatchery/RustGames/the_enchanters_ledger/src/data.rs:3) | JSON |
| toybox | Current game | [assets, capture, colors, data_loader, debug, events, notifications, …](D:/WebHatchery/RustGames/toybox/src/audio.rs:8) | — |
| world_machine | Current game | [assets, capture, data_loader, events, notifications, persistence, ui](D:/WebHatchery/RustGames/world_machine/src/data.rs:4) | — |

## Suggested migration order and validation

1. **JSON parsing/loading:** start with small embedded parsers, then platform/fallback loaders. Assert source-labeled errors and preserve runtime override/default policies. Keep fixtures for malformed/missing JSON.
2. **Text layout:** remove the exact duplicate measured wrappers first (`feast_frenzy`, `nanite_swarm`), then migrate character/byte-width UIs using real dimensions. Capture long labels, narrow/mobile layouts and deliberate line limits.
3. **WAV encoding and simple effects:** retain existing PCM for Stellar Legacy; match Last Assembly drag/expiry/rendering behavior before switching storage.
4. **Persistence extensions C1/C2:** introduce the shared API and migrate two consumers together. Validate old native paths, browser keys, legacy saves, backup order, corrupted saves and failed-write recovery.
5. **Camera/RNG compatibility:** migrate only with zoom-anchor, screen/world round-trip, input-claiming and seeded-output fixtures. Archived clients are lower priority unless being revived.

For future implementation changes, run the affected project's prescribed `publish.ps1` validation path. This report-only review deliberately has no build/publish result to claim.

## Review verification

The report generator checked that every finding's cited file and identifier exists and resolved its current line number. All current game manifests and the five archived client/game manifests were inspected for the toolkit dependency; both starter manifests were inspected separately. The inventory includes source references rather than treating Cargo declarations alone as adoption. Local adapters were manually read to remove the false positives listed above. No application source was edited.
