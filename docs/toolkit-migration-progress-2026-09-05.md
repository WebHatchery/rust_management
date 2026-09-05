# Toolkit migration progress — 5 September 2026

Scope: all 38 current games in `toolkit-review-2026-09-05.md`, processed one at a time. Archived games and starter templates are excluded. Game-owned rules, save schemas, and presentation remain local as specified in the review. Commit all modified/untracked project files after each game's validation, including pre-existing changes.

## Completed implementation and validation

| Game | Changes | Validation | Commit |
| --- | --- | --- | --- |
| auction_game | Embedded catalogue now uses toolkit labeled JSON parsing; included pre-existing game_page.json change. | 71 tests; fmt; Clippy all targets/features with warnings denied; default publish Windows/WebGL and Preview deployment pass. Repeat default publish confirms tracking succeeds without warnings. | `4c60cf8` |
| scrapyard | Toolkit JSON for contracts, modules, upgrades, tutorial and ship layouts; preserved fallback policies and variant transforms; included pre-existing game_page.json. | Nine tests; fmt; all-target/all-feature Clippy with warnings denied; default Windows/WebGL publish, Preview deployment and tracker pass. | `cbdbf69` |
| the_enchanters_ledger | Toolkit JSON for rune templates and practice ladder; corrected debug-only diagnostics action/handler/helper gating to remove a release warning; included pre-existing game_page.json. | 170 tests; fmt; all-target/all-feature Clippy with warnings denied in debug and release; final default Windows/WebGL publish and tracker pass cleanly. | `78e2806` |
| dragons_hoard | Toolkit JSON for achievement and hint definitions, preserving game validation and persistence; included pre-existing game_page.json. | 594 tests pass; 12 existing calibration/report tests ignored; fmt; all-target/all-feature Clippy with warnings denied; default Windows/WebGL publish and tracker pass cleanly. | `664ab94` |
| nightmare_shift | Toolkit JSON for all 14 content loaders; preserved fallback/required-data policies and glyph cleanup; fixed options div_ceil lint; included existing WSL deployment verification path change. | 248 tests; fmt; all-target/all-feature warning-strict Clippy; final default Windows/WebGL publish, tracker and deployment assembly verification pass. | `c38c224` |
| kaiju_sim | Toolkit native/WASM loaders for traits, balance and tournaments with explicit read-error fallback, malformed runtime rejection and semantic validation preserved. | 98 client/server tests; fmt; strict all-target/all-feature Clippy; default Windows/WebGL publish and Preview tracking pass. | `5fa9aef` |

| cultivation | Toolkit loads for all 18 native and 18 browser content sources; removed generic wrappers; preserved strict native versus lenient browser fallbacks; included pre-existing asset registry. | Five tests including shipped-catalogue regression; fmt; strict all-target/all-feature Clippy; default Windows/WebGL publish, 106 registered assets and Preview tracker pass. | `c3d4393` |

## Shared toolkit changes

- `4a14d46`: Added `load_json_file_with_fallback[_sync]` and `JsonFallbackPolicy::{ReadError, ReadOrParseError}` with labeled errors and explicit legacy fallback contracts. Added native frame-polled ureq transport so the optional net feature no longer pulls obsolete qws/net2 on Windows; WASM keeps quad-net. Completed requests retire after one result rather than later timing out or reporting disconnect. Validation: 396 all-feature library tests (including real local HTTP method/header/body/delivery checks), all-target/all-feature strict Clippy, net/analytics WASM compile, Kaiju Sim default publish. No standalone toolkit publish.ps1 exists. Do not revert to native quad-net: it produces a Rust future-incompatibility warning from net2's ambiguous Windows imports.

## Environment notes

- Default publisher cannot access shared `D:/WebHatchery/.cargo-target` from the restricted sandbox; approved elevated execution works. Use elevated Cargo/publish commands.
- Resolved transient issue: Auction Game initially reported Project Roost tracking connection refused at `http://127.0.0.1/project_roost/api/v1`. WSL Apache was active; Scrapyard tracking and a repeat Auction Game default publish both succeeded with no tracking warning. No configuration changes needed.
- Workspace root is not a Git repository. Each game, toolkit, and rust_management has its own repository. Scoped `git -c safe.directory=D:/WebHatchery/RustGames/<project>` permits sandbox Git use without modifying global trust.

## Remaining games

alchemy_tower, apartment, biofoundry, carriage_run, daemon_directorate, dragons_den, dungeon_core, dungeon_manager, eclipse_heart, feast_frenzy, finallanding, frontier, hatchspire, idle_hands, iron_fauna, last_assembly, master_thief, mirexis, monsterhall, mytherra, nanite_swarm, occupational_hazard, planet_trader, planetfall_engineer, realmseed, sentience, stellar_legacy, tarrowyn, tb_realms, toybox, world_machine.

Completed: 7 of 38 active games. Each completed game repository was clean after staging every changed/untracked project file and committing. No outstanding compiler, test or publisher warnings in these games.

Next candidate: apartment. AGENTS.md matches canonical instructions (compared). Local util/loader.rs exports generic load_json_config/load_json_or_default macros; many content modules also read/parse directly. Preserve native read-error fallback and browser embedding, remove local generic loaders. New shared fallback_sync API is currently native-only; adding a browser embedded-only counterpart may be appropriate. No apartment edits yet.

Finish JSON migrations, then larger loaders/text/effects and shared persistence/camera/RNG extensions with compatibility fixtures. Validate games with no reported duplication too. Required validation is each game's default `publish.ps1`; run tests, fmt and warning-strict all-feature Clippy, resolve findings and enforce 800-line Rust source limit. Avoid publishing concurrently with lint before fixes stabilize, to prevent republishing after release-only findings.
