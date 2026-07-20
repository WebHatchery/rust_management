# Love Season Implementation Plan

## Purpose

This document turns the current game concept into a buildable Rust/Macroquad project with explicit scope, data contracts, delivery gates, and validation steps. It is aligned with `GAME_DEVELOPMENT_GUIDE.md`, `CODE_STANDARDS.md`, and the current one-page design in `gdd.md`.

## Project Summary

Love Season is a romance-life sim built in Rust using Macroquad and macroquad-toolkit. The player navigates an 8-week reality-courtship season, balancing private romance, public image, and long-term compatibility before choosing an ending.

### Core Scope
- 8 in-game weeks
- 5 bachelors
- 3 rival contestants
- 1 primary estate/villa location with reusable scene variants
- 5 core player systems:
  - Affinity
  - Reputation
  - Stress
  - Authenticity
  - Future Fit
- 2-3 major events per week
- Multiple endings, including at least one self-choice ending

### Non-Goals For V1
- Full voice acting
- Complex animation systems
- Fully procedural event generation
- Branching that requires unique art for every route
- Custom editors or authoring tools beyond JSON and validation scripts

## Delivery Strategy

Build the game in three layers:

1. Foundation: architecture, loading, state machine, save system
2. Vertical slice: one fully playable week proving the loop works
3. Full content production: expand to all 8 weeks and ending variants

The vertical slice is a hard gate. Do not write all content before the first week is fun and technically stable.

## Target Architecture

Use a thin Macroquad layer for rendering and input only. Keep game rules in Rust structs and engine modules. UI must read state and return intents; it must not mutate gameplay state directly.

### Recommended Project Structure

```text
Cargo.toml
CODE_STANDARDS.md
GAME_DEVELOPMENT_GUIDE.md
IMPLEMENTATION_PLAN.md
publish.ps1
index.html
src/
  main.rs
  game.rs
  data/
    mod.rs
    loader.rs
    constants.rs
    character_data.rs
    event_data.rs
    dialogue_data.rs
  engine/
    mod.rs
    romance_engine.rs
    event_engine.rs
    scoring_engine.rs
  state/
    mod.rs
    game_state.rs
    persistence.rs
  ui/
    mod.rs
    core.rs
    components.rs
  screens/
    mod.rs
    menu.rs
    gameplay.rs
    results.rs
assets/
  constants.json
  characters.json
  events.json
  dialogue.json
  image_prompts.json
  localization/
    en.json
  images/
```

### Architectural Rules
- One active screen/state at a time
- Explicit `StateTransition` values only
- Stateless engine services where possible
- All balance values live in JSON under `assets/`
- Save data is versioned from day one
- Missing assets should degrade gracefully to placeholders, not crash

## Phase 1: Foundation Setup

### 1.1 Bootstrap Project
- Create `Cargo.toml` for Rust 2021
- Add dependencies:
  - `macroquad`
  - `macroquad-toolkit`
  - `serde` with `derive`
  - `serde_json`
  - `rand`
- Confirm Windows native and `wasm32-unknown-unknown` builds both compile
- Preserve existing `publish.ps1` and `index.html`, updating only if the wasm filename changes

### 1.2 Establish Module Skeleton
- Create the project structure shown above
- Add module-level `//!` docs
- Keep files near the repo’s size targets from `CODE_STANDARDS.md`

### 1.3 Implement Core Loop
- `main.rs` owns window configuration and frame loop
- `game.rs` owns top-level state and transitions
- Add initial screens:
  - Main menu
  - Gameplay
  - Results
- Add a temporary loading/fatal-error screen if startup loading fails

### Exit Criteria
- Game launches to menu
- Can enter gameplay and return to menu
- Can enter results screen through a debug path
- Native build succeeds
- WASM build succeeds

## Phase 2: Data Contracts And Loading

### 2.1 Define Static Data Schemas
- `constants.json`
  - pacing values
  - stat caps
  - relationship thresholds
  - weekly schedule settings
- `characters.json`
  - bachelor definitions
  - rival contestant definitions
  - player defaults
- `events.json`
  - event metadata
  - requirements
  - outcomes
  - week placement
- `dialogue.json`
  - scene lines
  - speaker IDs
  - choice text
  - conditional branches

### 2.2 Rust Data Types
- `BachelorData`
- `RivalData`
- `PlayerConfig`
- `EventData`
- `ChoiceData`
- `DialogueNode`
- `GameConstants`

### 2.3 Validation Rules
- Every ID must be unique
- Every event choice target must resolve
- Every speaker ID in dialogue must exist
- Week references must be within 1-8
- Ending IDs must map to valid result content
- Missing optional art/audio references must fall back safely

### 2.4 Loading Strategy
- Load all static data at startup
- Fail fast for malformed JSON
- Log precise file and field on load errors
- Keep runtime data immutable after loading

### Exit Criteria
- Startup loads all JSON successfully
- A validation pass catches malformed or dangling references
- Data schemas cover all core systems without hardcoded fallback logic in engine code

## Phase 3: Runtime State And Persistence

### 3.1 Runtime Game State
- `GamePhase` or equivalent enum for:
  - Menu
  - Playing
  - Paused
  - Results
- `RunState` for active playthrough data:
  - current week
  - current event
  - player stats
  - bachelor relationship state
  - rival state
  - unlocked scenes
  - seen dialogue flags
  - pending consequences

### 3.2 Save System
- JSON save format with explicit `version`
- Include:
  - slot metadata
  - playtime
  - timestamp
  - current phase
  - run state snapshot
- Support at least 3 save slots
- Handle corrupt save files without crashing

### 3.3 Migration And Recovery
- Reserve room for future save migration logic
- On version mismatch:
  - try migration if available
  - otherwise block load with a clear error message

### Exit Criteria
- New game creates a valid runtime state
- Save and load round-trip works
- Corrupt save is surfaced cleanly to the player

## Phase 4: Core Simulation Systems

### 4.1 Relationship Model
Each bachelor needs runtime stats for:
- attraction
- trust
- romantic momentum
- future fit
- exclusivity flags if needed for late-game branching

Keep the calculation code in `romance_engine.rs`. Prefer explicit result structs over tuples.

### 4.2 Public Pressure Systems
- Reputation split into sub-audiences if needed:
  - house
  - audience
  - matchmakers
- Stress affects option availability, dialogue quality, or event outcomes
- Authenticity tracks honest versus performative play

### 4.3 Weekly Progression
- Every week should include:
  - planning/setup beat
  - social/date beat
  - public pressure beat
  - resolution or cliffhanger beat
- Track which required beats have been satisfied before advancing

### 4.4 Outcome Resolution
- Choice consequences can modify:
  - relationship values
  - public reputation
  - stress
  - authenticity
  - future event availability
- Add a deterministic resolution order so chained effects are predictable

### Exit Criteria
- Player choices reliably modify stats and unlock/fail content
- Week advancement is deterministic and testable
- Relationship and ending math is inspectable and not hidden in UI code

## Phase 5: Event And Dialogue Pipeline

### 5.1 Event Structure
Each event should define:
- ID
- week
- scene type
- participants
- requirements
- intro dialogue node
- choices
- consequences
- completion flags

### 5.2 Dialogue Requirements
- Branching dialogue must support:
  - conditional lines
  - choice menus
  - stat checks
  - speaker changes
  - scene-end transitions
- Keep text and logic references separate where possible

### 5.3 Content Authoring Constraints
- Reuse scene templates to control scope
- Prefer reactive writing over fully bespoke branches
- Keep one critical path per week plus optional scenes
- Avoid exponential branching; use fold-back structure after meaningful divergence

### 5.4 Minimum Content Budget
- 1 opening week tutorialized introduction
- 6 middle weeks with escalating rivalry and romance
- 1 finale week with proposals and ending resolution
- At least:
  - 2 private scenes per bachelor across the season
  - 1 major rival interaction per rival
  - 1 public ceremony/confessional beat per week

### Exit Criteria
- One week is fully authored and playable end-to-end
- Writers can add new events by editing JSON rather than Rust code
- Dialogue flow supports all required branch patterns

## Phase 6: UI And Presentation

### 6.1 UI Principles
- Use macroquad-toolkit for buttons, panels, progress bars, and input helpers
- UI functions return intents such as `UiAction`
- Avoid embedding gameplay rules in screen render code

### 6.2 Required Screens
- Main menu
- Save/load screen
- Gameplay scene screen
- Weekly planner/schedule screen
- Pause/settings screen
- Results/epilogue screen

### 6.3 Gameplay HUD
- Week and event progress
- Relationship summaries
- Reputation/stress/authenticity indicators
- Current speakers and dialogue box
- Choice list with hover/focus states

### 6.4 Placeholder-First Asset Strategy
- Use simple panels, color blocking, and text-first layouts before final art
- Use placeholder portraits/backgrounds if final assets are not ready
- Track future image needs in `assets/image_prompts.json`

### Exit Criteria
- Full week is playable with placeholder visuals
- UI remains readable at 1280x720 and common window resize cases
- Mouse interaction is clear and consistent

## Phase 7: Vertical Slice Gate

Before scaling to all 8 weeks, complete a polished vertical slice containing:
- menu flow
- new game flow
- one complete week
- at least 2 bachelors
- at least 1 rival
- save/load
- one provisional ending path

### Slice Review Questions
- Is the central loop emotionally engaging?
- Are choices producing visible and understandable consequences?
- Is the schedule per week sustainable to author eight times?
- Are core stats adding tension rather than noise?
- Is the UI readable without art polish?

If the answer to any of these is no, revise systems now rather than multiplying content debt.

## Phase 8: Full Content Production

### 8.1 Expand Roster Content
- Finalize all 5 bachelor arcs
- Integrate 3 rival contestants into both public and private scenes
- Ensure each route has a distinct emotional fantasy and conflict pattern

### 8.2 Build Weekly Content
- Fill weeks 2-8 using the validated event structure
- Escalate tradeoffs:
  - chemistry vs safety
  - image vs honesty
  - status vs fit

### 8.3 Ending Matrix
Ship at least:
- 5 bachelor endings
- 1 self-choice ending
- 1 weak or hollow match ending
- optional mixed/bittersweet endings if schedule allows

### Exit Criteria
- Entire season playable from start to finish
- Every bachelor route has enough unique scenes to feel distinct
- Ending outcomes reflect both romance and growth systems

## Phase 9: Balancing, Testing, And Hardening

### 9.1 Automated Coverage Targets
Focus tests on:
- JSON loading and validation
- state transitions
- choice consequence resolution
- week advancement rules
- ending selection logic

### 9.2 Manual Test Matrix
- New game through each week
- High-stress run
- High-reputation run
- High-authenticity run
- Intentional “bad fit” romance run
- Save/load mid-scene and mid-week
- Repeated playthroughs for ending coverage

### 9.3 Balance Pass
- Check that no single bachelor dominates trivially
- Check that stress is threatening but recoverable
- Check that reputation matters without forcing one correct playstyle
- Check that self-choice ending is earned, not accidental

### 9.4 Performance And Stability
- Verify 60 fps on target hardware with placeholder assets and final assets
- Reduce repeated parsing or allocation in dialogue-heavy flows
- Confirm web build memory use remains acceptable

### Exit Criteria
- No blocker bugs on the test matrix
- No dangling content references
- Acceptable performance on Windows and WebGL

## Phase 10: Release Preparation

### 10.1 Build And Packaging
- Finalize release builds for Windows
- Finalize WebGL deployment path
- Ensure `publish.ps1` reflects the actual output names and folders

### 10.2 Asset Readiness
- Portraits
- background scenes
- UI decoration
- audio if included
- optimized image sizes for web deployment

### 10.3 Accessibility And Readability
- readable font sizes
- color contrast checks
- clear hover and selected states
- avoid conveying critical information with color alone

### Exit Criteria
- Release build reproducible from a clean checkout
- Web build launches from `index.html`
- Core route coverage complete

## Content Design Notes

### Bachelor Design Requirements
Each bachelor should have:
- clear outward fantasy
- hidden vulnerability
- incompatible value tension with the heroine
- growth or revelation scenes
- a believable marriage future, not just chemistry

### Rival Design Requirements
Rivals should not exist only to sabotage. Each needs:
- a clear strategy for surviving the season
- at least one sympathetic scene
- some overlap and some contrast with the heroine’s values

### Choice Design Requirements
Choices should usually express:
- emotional honesty
- social strategy
- risk appetite
- long-term compatibility instinct

Avoid filler choices that only alter flavor text.

## Major Risks And Mitigations

### Risk: Narrative Branch Explosion
- Mitigation: fold branches back after meaningful divergence
- Mitigation: keep per-week critical path small

### Risk: Systems Feel Opaque
- Mitigation: show consequence feedback after major choices
- Mitigation: expose enough stat direction for players to learn the model

### Risk: Content Production Slips
- Mitigation: finish one week first
- Mitigation: use reusable event templates and placeholders

### Risk: Web Build Issues
- Mitigation: compile to WASM early, not at the end
- Mitigation: keep asset pipeline simple and memory-conscious

## Milestones

### Milestone 1: Project Boots
- Menu, gameplay shell, results shell, successful data loading

### Milestone 2: Saveable Prototype
- Runtime state, save/load, stat mutation, placeholder UI

### Milestone 3: Vertical Slice
- One polished week, 2 bachelors, 1 rival, 1 ending

### Milestone 4: Full Season Alpha
- Weeks 1-8 playable with placeholder assets

### Milestone 5: Beta
- All routes complete, bugs reduced, balance mostly stable

### Milestone 6: Release Candidate
- Shipping assets integrated, performance validated, deployment verified

## Suggested Timeline

Assuming part-time solo development:

- Phase 1-2: 1-2 weeks
- Phase 3-4: 2 weeks
- Phase 5-7: 2-3 weeks
- Phase 8: 3-5 weeks
- Phase 9-10: 1-2 weeks

Estimated total: 9-14 weeks

## Definition Of Done

The project is ready to ship when:
- the full 8-week season is playable
- all core systems affect outcomes in understandable ways
- at least 7 endings are implemented and reachable
- save/load is stable
- Windows and WASM builds both work
- no critical content blockers remain
- the game delivers on the intended fantasy of public pressure, private vulnerability, and earned romantic choice
