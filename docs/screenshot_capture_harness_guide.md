# Adding a Headless Screenshot Harness to a macroquad Game

**Goal:** let a macroquad game screenshot *itself* — boot into a chosen scene,
render a fixed number of frames, write a PNG, and exit — with no interactive
window and no clicking. This makes UI/rendering changes visually verifiable
from a script (or by an AI agent that reads the PNG back), the same way
`finallanding`, `monsterhall`, and `carriage_run` do it.

The harness ships in the toolkit as `macroquad_toolkit::capture` plus a shared
wrapper script (`macroquad-toolkit/scripts/capture_ui.ps1`). Integrating a game
takes ~10 lines of `main.rs` plus one game-specific scene-seeding method.
Reference integrations: `carriage_run` (canonical), `finallanding` (custom
window conf + extra seeding env vars), `monsterhall` (config-driven window,
capture forces windowed). Verified on macroquad 0.4.15, Windows 11.

---

## How it works (the key idea)

You do **not** screenshot the OS window from outside. Instead the game binary
is instrumented: when a `PREFIX_CAPTURE_PATH` environment variable is set, the
normal interactive loop is replaced by a capture loop that

1. seeds a specific scene,
2. steps the simulation a fixed number of frames at a fixed timestep (so motion
   is deterministic),
3. calls macroquad's `get_screen_data().export_png(path)` — after drawing but
   **before** presenting the frame,
4. exits the process.

The wrapper script sets the env vars, runs the exe, and sanity-checks the PNG.
Because it is driven entirely by env vars, it needs no input and runs the same
way locally or in CI.

Env vars (replace `PREFIX` with a per-game prefix, e.g. `CARRIAGE`, `TFL`):

- `PREFIX_CAPTURE_PATH` — output PNG path; presence enables capture mode
- `PREFIX_CAPTURE_SCENE` — scene name passed to your seeding code (default `gameplay`)
- `PREFIX_CAPTURE_FRAMES` — frames to simulate before capture (default 150)
- `PREFIX_WINDOW_WIDTH` / `PREFIX_WINDOW_HEIGHT` — window size override

---

## Step 1 — Wire `macroquad_toolkit::capture` into `main.rs`

```rust
use macroquad_toolkit::capture;

fn window_conf() -> Conf {
    // Reads PREFIX_WINDOW_WIDTH/HEIGHT overrides and disables high_dpi while
    // capturing, so screenshots are pixel-aligned with the logical layout.
    capture::capture_window_conf("PREFIX", "My Game", 1280, 720)
}

#[macroquad::main(window_conf)]
async fn main() {
    let mut game = Game::new().await;

    if let Some(config) = capture::CaptureConfig::from_env("PREFIX") {
        game.begin_capture_scene(&config.scene);
        capture::run_capture(&config, |dt| {
            game.update(dt);
            game.draw();
        })
        .await;
        return;
    }

    loop { /* normal interactive loop */ }
}
```

`run_capture` handles the fixed timestep, the capture-before-present ordering,
and process exit. All env access is stubbed out on `wasm32`, so web builds are
unaffected.

If your game needs a custom `Conf` (extra fields, config-file-driven size),
build it by hand with `capture::env_i32` / `capture::env_bool` and
`capture::capture_requested("PREFIX")` — see `finallanding` (keeps a
`TFL_FULLSCREEN` var) and `monsterhall` (forces windowed while capturing).
`CaptureConfig`'s fields are public, so defaults can be overridden after
`from_env` (e.g. `finallanding` uses 8 frames instead of 150).

---

## Step 2 — Add scene seeding to `Game`

The capture needs to start in the state you want to photograph. Add a method
that puts the session into a named scene. Adapt the arms to your game's screens.

```rust
impl Game {
    /// Seed a specific scene for the screenshot harness.
    pub fn begin_capture_scene(&mut self, scene: &str) {
        match scene {
            "map" => self.session.open_map(),
            "loadout" => self.session.open_loadout(),
            "upgrades" => self.session.open_upgrades(),
            _ => {
                // Default: jump straight into gameplay. Pick an always-available
                // starting mission/level so this works on a fresh save.
                self.session.select_mission("first_level_id");
                if !self.session.start_selected_mission(&self.data) {
                    self.session.open_map();
                }
            }
        }
    }
}
```

This is optional — without it the capture photographs whatever the boot flow
lands on (e.g. `monsterhall` captures its main menu). Games can also seed via
their own env vars instead (`finallanding` uses `TFL_START_*` / `TFL_SEED_*`).

**Tip:** choose a fixed frame count (default 150 = ~2.5 s at 1/60) that is long
enough to show motion/spawns but short enough that the run can't end (e.g. the
player dying, or a timer expiring) and flip you into a results screen.

---

## Step 3 — Run the shared wrapper script

`macroquad-toolkit/scripts/capture_ui.ps1` builds the game, runs one capture
per scene, and fails loudly on missing/blank PNGs. It derives the package name,
exe path (via `cargo metadata`, so shared cargo target dirs just work), and
env-var prefix automatically:

```powershell
# From the game's directory:
& ..\macroquad-toolkit\scripts\capture_ui.ps1 -Scenes gameplay,map
& ..\macroquad-toolkit\scripts\capture_ui.ps1 -Scenes gameplay -SkipBuild

# Pass -Prefix when it differs from the package name:
& ..\macroquad-toolkit\scripts\capture_ui.ps1 -Prefix CARRIAGE -Scenes gameplay
```

PNGs land in `docs\verification\ui_<scene>.png` by default. Most games add a
thin per-game `scripts/capture_ui.ps1` wrapper that fills in the prefix and
default scenes (see `carriage_run` or `monsterhall`), so the whole flow is:

```powershell
./scripts/capture_ui.ps1
```

Or invoke the exe directly:

```powershell
$env:PREFIX_CAPTURE_PATH = "out.png"; $env:PREFIX_CAPTURE_SCENE = "gameplay"; & $exe
```

---

## Gotchas (learned the hard way)

These are handled by the toolkit, but explain symptoms if you deviate from it:

1. **Capture order is everything.** `get_screen_data()` must be called after
   drawing and **before** `next_frame().await`. Reading after `next_frame`
   returns a black/cleared buffer. Symptom: a valid-but-tiny PNG (~19 KB for
   1280×720) that renders solid black; a correct capture is much larger
   (~180 KB+). `run_capture` gets this right.
2. **DPI scaling changes the output size.** With `high_dpi: true`, the captured
   framebuffer can be 2× the logical size on scaled displays.
   `capture_window_conf` disables `high_dpi` while capturing.
3. **Deterministic motion.** Drive the capture loop with a fixed `dt` (1/60),
   not `get_frame_time()`, so repeated runs look identical and RNG-seeded
   spawns reproduce. `run_capture` passes `config.timestep` to your frame
   closure — use it. Vary the *scene* and *frame count*, not the timestep.

Still your responsibility:

4. **Runtime display overrides.** If the game applies saved display settings at
   startup (`set_fullscreen`, `request_new_screen_size`), skip that while
   `capture::capture_requested("PREFIX")` is true, or the capture size won't be
   deterministic (see `monsterhall/src/game.rs`).
5. **Startup notifications / toasts** may still be on screen in early frames.
   Either raise the frame count so they fade, or suppress them in capture mode.
6. **Stronger blank-frame checks.** The shared script's byte-size floor catches
   black/blank captures early. For stronger checks, read pixel regions back
   with `System.Drawing` and assert non-black ratios (see
   `finallanding/scripts/capture_ui_smoke.ps1` for a full region-assert
   example).

---

## How an AI agent uses this

After running the script, the agent reads the PNG with its file-read tool
(which renders images inline) to visually confirm the change — closing the loop
between "made an edit" and "saw it actually render correctly," without any
interactive window automation.

---

## Checklist to replicate

- [ ] Use `capture::capture_window_conf("PREFIX", title, w, h)` as `window_conf`
      (or build a custom `Conf` with the `capture::env_*` helpers).
- [ ] In `main`, branch on `capture::CaptureConfig::from_env("PREFIX")`, seed the
      scene, and call `capture::run_capture(&config, |dt| { update; draw; })`.
- [ ] Add `Game::begin_capture_scene(&str)` with arms for your screens (optional).
- [ ] Capture with `& ..\macroquad-toolkit\scripts\capture_ui.ps1 -Scenes ...`,
      optionally behind a thin per-game `scripts/capture_ui.ps1` wrapper.
- [ ] Read back a PNG, confirm it isn't black.

---

## Brief for agents: migrating every game in this repo

Everything below is repo state as of 2026-07-05 — trust it and skip the
re-discovery.

### Scope and status

Every workspace crate already depends on `macroquad-toolkit`, so no
`Cargo.toml` changes are needed — just `use macroquad_toolkit::capture;`.

- **Already migrated (skip):** `carriage_run`, `finallanding`, `monsterhall`.
- **Have hand-rolled harnesses to convert:** `dungeon_core`
  (`DUNGEON_CORE_CAPTURE_*`, follows the standard pattern) and `eclipse_heart`
  (`ECLIPSE_HEART_CAPTURE_*`, but uses `_CAPTURE_SCREEN` instead of
  `_CAPTURE_SCENE` and defaults to 8 frames). Neither has a capture script, so
  after confirming nothing else references the old names (grep the game's dir,
  including README), rename to the standard `_CAPTURE_SCENE` and keep their
  frame-count defaults.
- **Fresh integrations:** `ai_defense`, `alchemy_tower`, `apartment`,
  `auction_game`, `cultivation`, `dungeon_manager`, `food_frenzy`, `frontier`,
  `kaiju_sim`, `monstron`, `nanite_swarm`, `nightmare_shift`, `realmseed`,
  `scrapyard`, `sentience`, `the_enchanters_ledger`.
- **Judgment calls:** `template` (migrating it gives every future game the
  harness for free — worth doing), `toybox` (demo playground — low value,
  fine to skip). `kaiju_sim/kaiju_server` is a server crate, not a game.

### Rules

1. **Prefix:** package name uppercased with `-`/spaces as `_` (e.g.
   `nanite_swarm` → `NANITE_SWARM`). The shared script derives exactly this
   from `cargo metadata`, so games that follow it need no `-Prefix` argument.
   Never rename an existing harness's prefix that scripts or READMEs reference
   (`finallanding` keeps `TFL` for this reason).
2. **Whole frame body into the closure.** Games vary: some `update(dt)`, some
   `update()` with internal timing, some `clear_background` in `main`. Move
   everything the interactive loop does per frame — clear, update, draw — into
   the `run_capture` closure, ignoring `dt` if update takes none (see
   `finallanding/src/main.rs`).
3. **Grep for runtime display overrides** (`set_fullscreen`,
   `request_new_screen_size`) run at startup, and skip them when
   `capture::capture_requested("PREFIX")` — otherwise saved settings resize the
   window mid-capture and the PNG size is nondeterministic (see
   `monsterhall/src/game.rs`). Also force `fullscreen: false` while capturing
   if the game defaults to fullscreen.
4. **Scene seeding is optional.** If the game has an obvious state enum with
   reachable screens, add `begin_capture_scene` arms for 2–3 of them; otherwise
   capture the boot state (like `monsterhall`) and move on. Don't build new
   navigation plumbing just for the harness.
5. **Add a thin per-game wrapper** at `scripts/capture_ui.ps1` delegating to
   `macroquad-toolkit/scripts/capture_ui.ps1` with that game's default scenes
   (copy `monsterhall/scripts/capture_ui.ps1`).
6. **Don't touch** `finallanding/scripts/capture_ui_smoke.ps1` or other
   existing verification scripts — they drive the env vars directly and keep
   working as long as the env-var contract is preserved.

### Definition of done, per game

- `./scripts/capture_ui.ps1` succeeds from the game's directory.
- Read the PNG back visually. It must show the intended scene — a solid-black
  frame, an error dialog, or a loading screen is a failure even when the
  byte-size check passes (raise the frame count if it's still on a loading or
  toast frame).
- `cargo check -p <crate>` and
  `cargo check -p <crate> --target wasm32-unknown-unknown` both pass with no
  new warnings (all games ship web builds; the capture module stubs env access
  on wasm, so failures here mean the integration touched something it
  shouldn't).

Work one game at a time and report per-game outcomes; a build/capture failure
in one game must not block the rest.
