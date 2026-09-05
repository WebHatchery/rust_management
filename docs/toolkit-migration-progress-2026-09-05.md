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

| biofoundry | Audited existing shared content, persistence, camera, RNG, audio and UI; recorded evidence; fixed unrelated command-strip argument-count lint using existing HUD options. | 517 checks, fmt, strict Clippy, size limits, default Windows/WebGL publish with seven assets and Preview tracking pass. | `e4bfd8f` |

| daemon_directorate | Audited shared content, slots, RNG, UI and synthesis; migrated cue storage/playback to SoundManager; included pre-existing game page. | 160 checks including synth audits, fmt, strict Clippy, size limits, final Windows/WebGL Preview publish and tracking pass. | `82900ee` |

| dungeon_core | Shared SoundManager storage/playback preserves synthesis, layers and variant rotation; measured title wrapping; grouped drawer UI state to fix unrelated Clippy warning; recorded toolkit audit. | 151 checks, fmt, strict Clippy, size limits, default Windows/WebGL publish with seven assets and Preview tracking pass. | `fbff4db` |

| iron_fauna | Audited shared content, audio, RNG, slots, assets and UI; labeled content failures preserving duplicate rejection; included pre-existing game page. | 48 checks, fmt, strict Clippy, size limits, final default Windows/WebGL publish with 30 assets and Preview tracking pass. | `252c600` |

| master_thief | Shared generated sound storage/decoding/playback preserves synthesis, mute and gain; removed generic registry wrapper; audited remaining toolkit use; included pre-existing game page. | 367 checks, fmt, strict Clippy, size limits, final default Windows/WebGL publish with 11 assets and Preview tracking pass. | `dd9a48c` |

| occupational_hazard | Audited existing shared content, slots, assets, text and pointer input; no remaining generic infrastructure migration found; recorded evidence. | 28 checks, fmt, strict Clippy, size limits, default Windows/WebGL publish with five assets and Preview tracking pass. | `95ddde3` |

| planetfall_engineer | Labeled config/texture loading; audited shared infrastructure and established orthographic camera; fixed four unrelated Clippy findings; included pre-existing game page. | 76 checks, fmt, strict Clippy, size limits, default Windows/WebGL Preview publish and tracking pass. | `48908d0` |

| realmseed | Labeled all 13 toolkit content loads; audited shared camera/slots/assets/UI; fixed four unrelated parity lints; included pre-existing game page. | 27 checks, fmt, strict Clippy, size limits, default Windows/WebGL publish with ten assets and Preview tracking pass. | `bf97c12` |

| sentience | Labeled texture manifest; audited shared timing/slots/assets/UI; fixed missing catalog thumbnail with inspected toolkit opening-scene capture; included pre-existing game page. | 35 checks, fmt, strict Clippy, size limits, final default Windows/WebGL publish with 27 assets and thumbnail, Preview tracking pass. | `d6c8955` |

| toybox | Shared sound storage/playback and measured wrapping; labeled texture load; fixed unrelated gallery lint; included pre-existing TODO and game page. | 109 checks pass, two existing ignored; fmt, strict Clippy, size limits, default Windows/WebGL Preview publish and tracking pass. | `3bcfb30` |

| world_machine | Shared water ambience storage/playback preserves flow/loop/volume behavior; labeled texture loading; recorded toolkit audit. | 29 checks, fmt, strict Clippy, size limits, default Windows/WebGL Preview publish and tracking pass. | `8dd5a10` |

| dragons_den | Audited existing toolkit content/slots/RNG/achievements/effects/UI; refreshed standalone toolkit lockfile; included pre-existing game page. | 61 checks, fmt, strict Clippy, size limits, default Windows/WebGL Preview publish and tracking pass. | `a33cc76` |

| mytherra | Labeled remaining direct core content loads; audited all five crates and retained domain SQL storage; refreshed toolkit lockfile. | 360 workspace checks pass, three existing live-server tests ignored; fmt, strict workspace Clippy, size limits, default Windows/WebGL Preview publish and tracking pass. | `716df1d` |

| tarrowyn | Labeled client texture loading; audited client/protocol/server toolkit integration and established bounded authority persistence. | 882 workspace checks, fmt, strict workspace Clippy, project size limits, default Windows/WebGL publish with 14 assets and Preview tracking pass. | `4d48de9` |

| carriage_run | C1 raw three-generation slot backups, failure propagation, corrupt/future primary protection and shared recovery; labeled texture loading. | 146 checks pass, one existing ignored; 401 toolkit checks, fmt, strict Clippy, clean-commit default Windows/WebGL Preview publish and tracking pass. | `12a2bd2` |

| monsterhall | Shared native raw backups and validated explicit legacy imports; read-only version probes, future primary protection, original paths/bytes and game migrations retained. | 237 tests pass, one existing ignored; fmt, strict Clippy, default Windows/WebGL Preview publish and tracking pass. | `a517a82` |

| nanite_swarm | Shared three-generation raw backups, future primary protection, safe post-recovery saving, camera pan/zoom/bounds and measured tutorial/launch/HUD text. Saved schemas and key names retained. | 743 tests, fmt, strict Clippy, final default Windows/WebGL publish with 64 assets and Preview tracking; desktop and 390px mobile captures pass. | `1a18392` |

| mirexis | Shared camera transforms for both maps, bounded dialogue/field notes, measured event/outsider wrapping and font-style truncation; fixed seven unrelated Clippy findings. | 520 game tests, 403 toolkit tests, fmt, strict Clippy, default Windows/WebGL publish with 39 assets and Preview tracking; release captures pass. | `5cdd5a5` |

| finallanding | Shared measured fitting across UI, bounded narrow tooltips, existing legacy RNG verified; fixed overflowing colonist rail and compact inspector portraits. | 159 tests, fmt, strict Clippy, default Windows/WebGL Preview publish/tracking, four release captures pass. | `f6cfd02` |

| hatchspire | Shared measured wrapping/fitting throughout help, tower, field guide, journal, town logs, tutorial and finale; literal path whitespace preserved; existing toolkit map RNG compatibility retained. | 182 game tests, 405 toolkit tests, fmt, strict Clippy, size limits, default Windows/WebGL Preview publish/tracking and five inspected release captures pass. | `4232049` |

## Shared toolkit changes

- `eac0ac7`: Measured literal wrapping preserves every character and repeated space in paths; variable-width, Unicode, exact-fit and narrow-width fixtures. 405 all-feature toolkit tests, strict Clippy and Hatchspire native/WebGL publisher pass.

- `436bbef`: SlotSaveStore retains native slot paths and browser qualified/legacy reads; shared envelope encoder and migration decoder used by ordinary slot APIs and backup chains. 401 toolkit checks and strict Clippy; Carriage Run native/WebGL publish confirms platform integration.

- `5cee233`: ParticleSystem explicit frame-drag compatibility update; exact legacy position/velocity/lifetime fixture including zero dt and expiry. 399 all-feature toolkit tests, strict Clippy and Last Assembly Windows/WASM publish pass.

- `4844647`: DataRegistry embedded-array merging, first-readable-directory sorted overlays with diagnostics, consuming map conversion, and Path-compatible synchronous JSON loading. WASM loose sync reads return an explicit unsupported error. Validation: 398 all-feature toolkit tests, strict Clippy and Dungeon Manager WASM/default publish.

- `a59efb3`: Synchronous explicit-policy JSON fallback loader now has a WASM embedded-only counterpart. Async API still fetches browser overrides. Validation: 396 toolkit all-feature library tests, strict all-feature Clippy, Apartment WASM check and default publisher.

- `4a14d46`: Added `load_json_file_with_fallback[_sync]` and `JsonFallbackPolicy::{ReadError, ReadOrParseError}` with labeled errors and explicit legacy fallback contracts. Added native frame-polled ureq transport so the optional net feature no longer pulls obsolete qws/net2 on Windows; WASM keeps quad-net. Completed requests retire after one result rather than later timing out or reporting disconnect. Validation: 396 all-feature library tests (including real local HTTP method/header/body/delivery checks), all-target/all-feature strict Clippy, net/analytics WASM compile, Kaiju Sim default publish. No standalone toolkit publish.ps1 exists. Do not revert to native quad-net: it produces a Rust future-incompatibility warning from net2's ambiguous Windows imports.

## Environment notes

- Stellar Legacy debug binary was locked by a running user game (PID 8632 when inspected). Do not kill it; release-profile full/demo tests passed and default publishing worked. No blocker remains.

- Default publisher cannot access shared `D:/WebHatchery/.cargo-target` from the restricted sandbox; approved elevated execution works. Use elevated Cargo/publish commands.
- Resolved transient issue: Auction Game initially reported Project Roost tracking connection refused at `http://127.0.0.1/project_roost/api/v1`. WSL Apache was active; Scrapyard tracking and a repeat Auction Game default publish both succeeded with no tracking warning. No configuration changes needed.
- Workspace root is not a Git repository. Each game, toolkit, and rust_management has its own repository. Scoped `git -c safe.directory=D:/WebHatchery/RustGames/<project>` permits sandbox Git use without modifying global trust.

## Completion

Completed: 38 of 38 active games. No games remain. All recommended shared infrastructure migrations are implemented or verified already present; game-owned rules, save schemas and compatibility policies remain local as required by the review.

Each game passed its recorded tests, formatting, warning-strict Clippy and default publish.ps1. Existing intentionally ignored tests are listed per game above. Findings encountered during validation were resolved. Every modified/untracked project file was staged and committed per game, including pre-existing changes.

Final audit verified all 38 migration commits remain in each game history and all game working trees are clean. Nightmare Shift subsequently merged as 0a71eed with an identical tree to its recorded migration commit c38c224. The toolkit and management repositories are also committed and clean. Archived games and starter templates were outside this goal.

Toolkit follow-up: 3827168 adds explicit-path FileSaveStore and raw validated browser imports; 403 toolkit tests and strict Clippy pass, Monsterhall native/WebGL publisher passes.



Toolkit follow-up: c8f496a adds styled measured truncation preserving explicit built-in fonts; 403 toolkit checks and Mirexis native/WebGL publisher pass.
