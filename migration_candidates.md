# Rust Migration Candidates

Survey of the React/PHP games under `game_apps/` for which would make good Rust ports, given an AI-driven dev process where **high art dependency is a liability** — numbers/icons/abstract visuals are cheap, character portraits/card illustrations/creature rosters are expensive. Cross-referenced against the genres already shipped in `RustGames/standing.md` (as of 2026-07-18) to flag genre gaps vs. redundancy.

Already migrated and excluded from consideration: `nightmare_shift` → horror taxi survival, `food_frenzy` → `feast_frenzy` (cozy-macabre restaurant management), `dungeon_core` → dungeon-defense monster breeding sim.

## Tier 1 — new genre + near-zero art bill (best picks)

| Game | Why it fits |
|---|---|
| **`mytherra`** | God-game/"watch and nudge" simulation — no equivalent in the Rust catalog at all. Presentation is event logs, world-state numbers, emergent narrative text — exactly the kind of system an engineering-heavy team can build without an artist. |
| **`dragons_den`** | Idle/incremental with prestige loop. Zero overlap in Rust roster — idle games are the single lowest-art genre that exists (icons + big numbers), yet nothing like it has been built. |
| **`tb_realms`** (Tradeborn Realms) | Fantasy stock-market/trading sim. Distinct loop from `auction_game` (price speculation vs. one-shot auctions) — sells on charts and numbers, not art. |
| **`hive_mind`** | Swarm/collective-intelligence sim — abstract node-graph and particle-swarm visuals, the same art profile that made `nanite_swarm` cheap. No characters, no creatures. |
| **`kingdom_wars`** | Explicitly "text-based strategy." Loose genre overlap with `frontier`/`realmseed` but built to need essentially no art at all. |
| **`planet_trader`** | Terraform-and-flip loop is distinct from `auction_game`'s tycoon flavor, and could directly reuse `nanite_swarm`'s already-built planetary terrain renderer instead of commissioning planet art. |

## Tier 2 — genre gap, bigger scope

| Game | Why it fits |
|---|---|
| **`xytherra`** | True 4X grand strategy (explore/expand/exploit/exterminate) — the single biggest genre hole in the whole catalog, since existing "realm" games are kingdom-builders, not full 4X. Starmap/planet icons keep art low, but 4X scope is inherently large — a bigger bet, not a quick win. |
| **`daemon_directorate`** | Corporate-satire strategy/squad management. Satire tone lets you lean on abstract corporate iconography instead of character art. Unique genre, no Rust analog. |
| **`master_thief`** | Heist crew-dispatch sim — automated-mission structure like `carriage_run`'s expedition meta-game, so art stays to icons/UI. Distinct from anything shipped. |
| **`last_hope`** | Branching post-apocalyptic narrative survival. The Rust catalog is systems-sim-heavy; nothing is choice/story-driven like this. Costs writing, not art. |

## Tier 3 — decent but partially redundant genre-wise

- **`empire_builder`** — Majesty-style real-time hero-AI kingdom; overlaps `frontier`/`realmseed` but the auto-battling hero AI differentiates it.
- **`stellar_legacy`** — generational dynasty-management strategy; conceptually close to `apartment`'s succession/portfolio mechanic, different setting.
- **`ashes_of_aeloria`** — node-map campaign strategy; overlaps `dungeon_manager`/`realmseed`'s campaign structure.
- **`dungeon_crawler`** — classic party/blobber dungeon crawl; genre-adjacent to `iron_fauna` but exploration-first rather than combat-chassis-first.
- **`blacksmith_forge`** — crafting sim w/ timing minigames; overlaps `the_enchanters_ledger`'s workshop niche but order/customer loop differs.

## Bad fits — worth naming explicitly

- **`chyrralon`** (CCG) — needs a 100+ card art catalogue; `eclipse_heart`'s own estimate already shows this is the costliest tax even *with* Rust's other savings.
- **`heart_season`, `interstellar_romance`** (dating sims) — the genre sells on companion portraits/art appeal; going low-art undercuts the actual fantasy. `heart_season` also wants real multiplayer/netcode, a second complexity axis beyond art.
- **`magical_girl`** — same "character art sells it" problem, plus roster-management mechanics redundant with `monsterhall`/`adventurer_guild`.
- **`kemo_sim`, `monster_farm`, `robot_battler`, `monsterworks`, `xenomorph_park`** — creature-collection/factory-automation is already 3-4 deep in the Rust catalog (`kaiju_sim`, `monsterhall`, `monstron`, `iron_fauna`, `biofoundry`, `nanite_swarm`); these add redundancy without a strong enough unique hook.
- **`adventurer_guild`** — genre thoroughly covered by `monsterhall` already.
- **`mmo_sandbox`** — kitchen-sink tech demo touching crafting/guilds/PvP/market, not a focused single game worth porting as one project.
- **`dungeon_master`** — a GM utility toolkit, not really a game.
- **`emoji_tower`** — art cost is literally zero (it's emoji), but the tower-defense slot is already filled by `ai_defense`.

## Top pick

`mytherra` — the cleanest genre gap, the fantasy (watch a world, nudge it, no direct control) is inherently about simulation depth over spectacle, and it plays straight to what an AI-driven, artist-light dev process is actually good at.
