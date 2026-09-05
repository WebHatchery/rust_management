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
| apartment | Toolkit native-runtime/browser-embedded loading for all 12 active content sources; deleted unused generic loader macros; preserved fallback/default rules. | 155 tests pass, one pre-existing test ignored; fmt; strict Clippy; WASM check; default Windows/WebGL publish and Preview tracking pass. | `7036d36` |
| stellar_legacy | Toolkit wav_bytes and SoundManager for all generated cues/ambience; preserved PCM, envelopes and gains; added exact-byte WAV fixture. | 481 checks pass in each full/demo release run (one pre-existing ignored test each); fmt; strict all-feature Clippy; default Windows/WebGL publish, tracker, packaged Windows render and real-browser WebGL smoke pass. | `f6428ce` |

| dungeon_manager | Toolkit catalogues, balance calculator, content packs and maps; shared campaign/scenario registry overlays preserve ordering and fallback; included pre-existing asset registry. | 295 tests pass, one existing ignored; fmt; strict all-feature Clippy; WASM check; default Windows/WebGL publish with 177 assets and Preview tracking pass. | `89bb0fd` |

| eclipse_heart | Toolkit native/browser content loads; removed generic JSON wrappers and three local text-wrapping loops; measured panel widths and capped deck previews; included pre-existing game page and asset registry. | 50 tests, fmt, strict all-feature Clippy, default Windows/WebGL publish with 62 assets and Preview tracking pass. | `4e69cba` |

| feast_frenzy | Toolkit content loads with corrected per-catalogue runtime paths; shared wrapping in three panels; existing toolkit C2 import validates and preserves legacy bytes, propagates copy failures and rejects future saves; included pre-existing game page. | 39 game tests, four shared import tests, fmt, strict Clippy and default Windows/WebGL publish/Preview tracking pass. | `26507ce` |

| frontier | Toolkit content and texture-discovery JSON loading; removed two local macros; shared measured wrapping for tooltip, base, combat, missions and event descriptions. | 23 tests, fmt, strict Clippy, final default Windows/WebGL publish with 49 assets and Preview tracking pass. | `48dd019` |

| last_assembly | Toolkit UI-string fallback and particle storage/integration/expiry with legacy frame drag and unchanged emission/rendering; fixed unrelated documentation and build-panel Clippy findings. | 52 game tests, 399 shared tests, fmt, strict Clippy, default Windows/WebGL Preview publish and tracker pass. | `7387fc9` |

| idle_hands | Toolkit measured wrapping in portrait/landscape tutorials, FreeCell help and results with readable font floor and actual panel widths; retained line limits and touch controls, removed obsolete byte-count assertion. | 897 tests, fmt, strict Clippy, default Windows/WebGL Preview publish and tracker pass. | `3babb4c` |

| planet_trader | Shared SeededRng primitive with preserved legacy mixing, low-bit floats and zero fixed point; measured demand-label truncation. | 47 tests including five-seed/128-draw integer and float compatibility, fmt, strict Clippy, default Windows/WebGL Preview publish and tracking pass. | `32ccd78` |

| tb_realms | All UI truncation uses toolkit pixel widths and actual fonts, reserving ticket metadata; boxed oversized network request variant; included pre-existing game page. | 109 checks pass, three existing ignored; fmt, strict Clippy, default Windows/WebGL Preview publish and tracking pass. | `635f543` |

| alchemy_tower | Shared formula-detail wrapping with capped lines and measured ellipsis; native toolkit save loading; browser-only decoder gating; included pre-existing loop notes. | 229 checks, publisher own 228-test rerun, fmt, strict Clippy, default Windows/WebGL publish with 472 assets and Preview tracking pass. | `f0b2072` |

## Shared toolkit changes

- `5cee233`: ParticleSystem explicit frame-drag compatibility update; exact legacy position/velocity/lifetime fixture including zero dt and expiry. 399 all-feature toolkit tests, strict Clippy and Last Assembly Windows/WASM publish pass.

- `4844647`: DataRegistry embedded-array merging, first-readable-directory sorted overlays with diagnostics, consuming map conversion, and Path-compatible synchronous JSON loading. WASM loose sync reads return an explicit unsupported error. Validation: 398 all-feature toolkit tests, strict Clippy and Dungeon Manager WASM/default publish.

- `a59efb3`: Synchronous explicit-policy JSON fallback loader now has a WASM embedded-only counterpart. Async API still fetches browser overrides. Validation: 396 toolkit all-feature library tests, strict all-feature Clippy, Apartment WASM check and default publisher.

- `4a14d46`: Added `load_json_file_with_fallback[_sync]` and `JsonFallbackPolicy::{ReadError, ReadOrParseError}` with labeled errors and explicit legacy fallback contracts. Added native frame-polled ureq transport so the optional net feature no longer pulls obsolete qws/net2 on Windows; WASM keeps quad-net. Completed requests retire after one result rather than later timing out or reporting disconnect. Validation: 396 all-feature library tests (including real local HTTP method/header/body/delivery checks), all-target/all-feature strict Clippy, net/analytics WASM compile, Kaiju Sim default publish. No standalone toolkit publish.ps1 exists. Do not revert to native quad-net: it produces a Rust future-incompatibility warning from net2's ambiguous Windows imports.

## Environment notes

- Stellar Legacy debug binary was locked by a running user game (PID 8632 when inspected). Do not kill it; release-profile full/demo tests passed and default publishing worked. No blocker remains.

- Default publisher cannot access shared `D:/WebHatchery/.cargo-target` from the restricted sandbox; approved elevated execution works. Use elevated Cargo/publish commands.
- Resolved transient issue: Auction Game initially reported Project Roost tracking connection refused at `http://127.0.0.1/project_roost/api/v1`. WSL Apache was active; Scrapyard tracking and a repeat Auction Game default publish both succeeded with no tracking warning. No configuration changes needed.
- Workspace root is not a Git repository. Each game, toolkit, and rust_management has its own repository. Scoped `git -c safe.directory=D:/WebHatchery/RustGames/<project>` permits sandbox Git use without modifying global trust.

## Remaining games

biofoundry, carriage_run, daemon_directorate, dragons_den, dungeon_core, finallanding, hatchspire, iron_fauna, master_thief, mirexis, monsterhall, mytherra, nanite_swarm, occupational_hazard, planetfall_engineer, realmseed, sentience, tarrowyn, toybox, world_machine.

Completed: 18 of 38 active games. Each completed game repository was clean after staging every changed/untracked project file and committing. No outstanding compiler, test or publisher warnings in these games.

Next candidate: biofoundry audit and validation. Canonical AGENTS.md matches, worktree initially clean. Initial source search finds only ui/hud/panels.rs using the last word of a machine name; inspect context, likely intentional display name. No original review finding. Inspect toolkit adoption, source sizes and run all checks/default publisher; record evidence in a game document if there is no source migration needed. No Biofoundry edits yet. Toolkit already includes C1 backups and C2 legacy APIs (legacy commit 37702aa); inspect authoritative code before adding extensions.

Finish JSON migrations, then larger loaders/text/effects and shared persistence/camera/RNG extensions with compatibility fixtures. Validate games with no reported duplication too. Required validation is each game's default `publish.ps1`; run tests, fmt and warning-strict all-feature Clippy, resolve findings and enforce 800-line Rust source limit. Avoid publishing concurrently with lint before fixes stabilize, to prevent republishing after release-only findings.
