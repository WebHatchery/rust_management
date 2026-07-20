# [Game Name] — Game Design Document

> **How to use this template:** Copy this file into the new game's directory as `gdd.md`
> (or `game_design.md`) before writing any Rust. Fill in every bracketed prompt. Delete
> a section only if it's genuinely not applicable — don't leave it blank. This doc is the
> single source of truth an AI implementer reads before touching code, so it should answer
> "what do I build" *and* "with which toolkit piece" without needing `CLAUDE.md` explained
> again. Keep it a living document — update it as systems get prototyped, the same way
> `iron_fauna/game_design.md` and `realmseed/gdd.md` do (mark resolved opens with
> `~~strikethrough~~ — Resolved: ...`).
>
> Sources: `[old game path under game_apps/]`, `docs/GAME_DEVELOPMENT_GUIDE.md`,
> `docs/CODE_STANDARDS.md`, `docs/MACROQUAD_TOOLKIT.md`, `migration_candidates.md`.

---

## 0. Migration Snapshot

*This section only exists because the game started life as a React/PHP app. It's the
bridge between "what the old game did" and "what the Rust port keeps, cuts, or changes."*

- **Old game:** `game_apps/[slug]/` — [one-line description of what it was].
- **Why it was picked:** [pull the relevant line from `migration_candidates.md` — genre
  gap? art-cost profile? which tier?]
- **Art-liability audit** — the whole point of porting this instead of a high-art game.
  List every asset class the old game leaned on and what replaces it:

  | Old asset (web) | Art cost | Rust replacement |
  | --- | --- | --- |
  | [e.g. character portraits] | High | [e.g. cut — represented as name + stat block] |
  | [e.g. card illustrations] | High | [e.g. icon + color-coded border, `colors` module] |
  | [e.g. UI chrome/CSS] | Low | [toolkit `ui`/`fx` widgets] |
  | [e.g. map/world art] | Medium | [procedural/abstract via `raster`/`fx`, or reused from `[other game]`] |

  If nothing in the old game required expensive art, say so explicitly — don't leave the
  table looking incomplete.

- **Mechanic carry-over table** — be explicit about what's 1:1, what's redesigned, what's cut:

  | Old mechanic | Disposition | Notes |
  | --- | --- | --- |
  | [mechanic] | Keep as-is | [ ] |
  | [mechanic] | Redesign | [why — e.g. turn-based UI doesn't map to immediate-mode, real-time fits better] |
  | [mechanic] | Cut | [why — e.g. required art-heavy roster, or real-money/multiplayer scope creep] |

- **Explicitly out of scope for the port:** [multiplayer/netcode, real-money mechanics,
  anything the old game had that this list says to drop]

---

## 1. High Concept

- **Pitch:** [1–3 sentence hook, present tense, in the tone the game will actually have]
- **Genre:** [be specific — cross-check `standing.md` so you know what's already shipped
  in this catalog and aren't quietly duplicating a genre]
- **Perspective & presentation:** [2D top-down / side-view / isometric-via-2D-sprites /
  UI-only-no-world-view — state it, since it decides how much of the toolkit's `camera`
  and `sprite` modules you need at all]
- **Tone:** [ ]
- **Comparables:** [1–3 existing games, what each contributes to the mashup]
- **Audience:** [ ]
- **Scope:** [prototype / vertical slice / full game — be honest, this drives §11]
- **Platforms:** itch.io + Steam via WebGL and native Windows (standard for this catalog)

---

## 2. Design Pillars

List 3–5. Each pillar should be checkable against a build — "the player should always
feel X" is only useful if a system in §5 actually produces X.

1. **[Pillar name].** [What it means, why it matters, what would violate it.]
2. ...

---

## 3. Core Loop

[The one loop the player repeats most. Write it as a numbered sequence of verbs, the way
`iron_fauna/game_design.md` §4.1 does. If there's a secondary/meta loop (session loop vs.
campaign loop), give it its own numbered list.]

1. ...

---

## 4. Player Role & Verbs

- **The player is:** [role/persona]
- **The player directly controls:** [ ]
- **The player does NOT control:** [be explicit about what's simulated/autonomous —
  this matters a lot for sim/strategy games in this catalog, see `realmseed/gdd.md` §4]
- **Core verb list:** [the action vocabulary — naming these consistently now saves a
  UI-action-enum bikeshed later; see §9]

---

## 5. Systems & Mechanics

*This is the biggest section and should carry actual numbers, not just prose — an AI
implementer needs formulas and starting values to write `assets/*.json`, not adjectives.
Copy `realmseed/gdd.md` §9–§16's style: a stat table, a formula in a fenced block, a
threshold table.*

### 5.1 [System name, e.g. "Resource Economy"]

| Stat/Resource | Meaning | Range/Units |
| --- | --- | --- |
| | | |

```text
[formula, e.g. food_consumed = population * 0.25 * tier_modifier]
```

### 5.2 [System name, e.g. "Combat" / "Conflict Resolution"]

[Repeat the stat-table + formula pattern per major system. Add as many subsections as the
game needs. Each one should be resolvable into a JSON schema in §6.]

### 5.3 Randomness & Determinism

- **What's randomized:** [ ]
- **What must stay deterministic:** [replays, saves, tests — per `CODE_STANDARDS.md`
  §5, isolate RNG behind toolkit's `rng` module rather than ad hoc `macroquad::rand`]

---

## 6. Data Model (`assets/*.json`)

*Data-driven design is a hard rule for this codebase — balance values and content must
live in JSON, loaded via `serde`/toolkit `data_loader` or `DataRegistry`, not hardcoded
Rust constants. Sketch the shape now so the loader code in `data/` is a mechanical step.*

```json
// assets/[name].json — [one line: what this file defines]
{
  "id": "string",
  "...": "..."
}
```

List every top-level data file the game will need:

| File | Defines | Loaded via |
| --- | --- | --- |
| `assets/[x].json` | [ ] | `data_loader::load_json_file` / `DataRegistry` |
| `assets/data/texture_manifest.json` | Sprite/texture manifest | `AssetManager` |
| `assets/data/game_config.json` | [tunable constants, difficulty presets] | [ ] |

Native builds may read `assets/` from disk with an `include_str!` fallback for WASM —
decide now whether this game needs disk hot-reload or should embed-only like `template/`.

---

## 7. World & Progression Structure

- **World layout:** [single screen / connected maps / procedural / hub-and-spoke — state
  which, and whether `FlatGrid`/tilemap toolkit pieces are involved]
- **Session/campaign length:** [ ]
- **Progression stages:** [table of stages/tiers/acts, like `realmseed/gdd.md` §17]
- **Save/persistence model:** what needs to survive a session — use
  `save_to_slot_with_version` / `load_from_slot_with_migration` (see `template/`) rather
  than a bespoke format.

---

## 8. Content Inventory

*Concrete counts, not "a lot of content" — this is what makes scope estimable and stops
an AI implementer from either under- or over-building.*

| Content type | Prototype target | Full target |
| --- | ---: | ---: |
| [e.g. creature species / card templates / event families] | | |
| [e.g. maps/regions/levels] | | |

---

## 9. UI/UX & Screen Flow

*UI is a pure view layer per `CODE_STANDARDS.md` §7 — it reads state and returns
`UiAction` intents; a `*_actions.rs` dispatcher applies them. Never reach into state from
a panel. List screens and the toolkit widgets each one leans on so this isn't invented
per-screen during implementation.*

| Screen | Purpose | Toolkit pieces |
| --- | --- | --- |
| [Main Menu] | | `VirtualUi`, `SurfaceStyle`, buttons |
| [Main Play Screen] | | `Camera2D`, `FlatGrid`, `GridLayout` |
| [Detail/Selection Panel] | | `TextStyle`, tooltips, meters, badges |
| [Event/Modal] | | `NotificationManager` / modal surface |

Interaction flow (mirror `realmseed/gdd.md` §20's numbered flows if the game has
turn/season structure; otherwise describe the frame-by-frame input→action→state path):

1. ...

---

## 10. Toolkit Mapping

*Explicit checklist against `macroquad-toolkit`'s actual modules — forces "reach for the
toolkit first" (per `AGENTS.md`) to happen at design time, not as an afterthought during
implementation. Mark each row Yes/No/Maybe and note the specific toolkit type/function.*

| Need | Toolkit module | Using it? | Notes |
| --- | --- | --- | --- |
| Input handling | `input` | | |
| Widgets/layout/text | `ui` (`VirtualUi`, `GridLayout`, `SurfaceStyle`, `TextStyle`, meters, badges, tabs, scroll) | | |
| Textures/manifest | `assets` (`AssetManager`) | | |
| Camera/pan/zoom | `camera` | | |
| Cross-system messaging | `events` (`EventBus<UiAction>`) | | |
| Palette | `colors` | | |
| Vector/grid math | `math` | | |
| Frame timing | `timing` | | |
| Particles/juice | `fx` | | |
| User settings | `settings` | | |
| Unlocks/achievements | `achievements` | | |
| Dev overlay | `debug` | | |
| Deterministic randomness | `rng` | | |
| Sprite animation | `sprite` | | |
| Procedural images | `raster` | | |
| Headless screenshot capture | `capture` | Yes (required for every game) | see `docs/screenshot_capture_harness_guide.md` |
| Save/load | `persistence` (`save_to_slot_with_version`, etc.) | | |
| Tile grid / fog / pathing | `FlatGrid`, `FogState`, line-of-sight, flood-fill | | |

If a need isn't covered by any row, that's a signal to raise a toolkit upgrade rather than
build a project-local alternative — flag it in §12 instead of silently deciding solo.

---

## 11. Architecture Skeleton

*Sketch the module list before coding so file layout follows `GAME_DEVELOPMENT_GUIDE.md`
from the first commit — `foo.rs` + `foo/` children, never `mod.rs`, 800-line hard limit.*

```
src/
├── main.rs
├── game.rs            # Game struct, update()/draw() loop
├── state.rs            # GameState enum + re-exports
├── state/
│   ├── menu.rs
│   └── gameplay.rs
├── data.rs             # data module root
├── data/
│   └── [loader per content type]
├── engine.rs / simulation.rs   # stateless services: receive state, return results
├── engine/
│   └── [...]
├── ui.rs
├── ui/
│   └── [panel per screen]
└── save.rs
```

- **`GameState` variants:** [Menu, Gameplay, ... — one per screen in §9]
- **Key stateless services (`engine`/`simulation`):** [the pure-function layer that
  operates on state — e.g. `combat_resolver`, `season_advancer`]
- **State that must persist across frames but never leak into UI:** [ ]

---

## 12. Non-Goals / Open Questions

- **Explicitly not building (v1):** [bullet the things a reader would reasonably assume
  are in scope but aren't — mirrors `iron_fauna/game_design.md` §12 and
  `GAME_DEVELOPMENT_GUIDE.md`'s Non-Goals]
- **Open questions**, in priority order — resolve top-down, strike through when settled:

  1. [ ]
  2. [ ]

---

## 13. Milestones

*Stage scope like `realmseed/gdd.md` §2 (Prototype vs. Full target table) so "done" is
checkable. Smallest complete loop first.*

| Milestone | Proves | Target content |
| --- | --- | --- |
| M1 — Mechanical proof | Core loop works end-to-end with placeholder data | [minimum] |
| M2 — Playable prototype | [ ] | [ ] |
| M3 — Content-complete | [ ] | [ ] |

After M1, follow the standard per-game loop: `cargo clippy --all-targets --all-features -- -D warnings`,
`cargo test`, then `.\publish.ps1` from the game directory to verify at the shared preview
root — same validation path as every other game in this repo, no exceptions for being new.
