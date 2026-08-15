# Toolkit and architecture orientation

## Shared toolkit ownership

`macroquad-toolkit` is an independent sibling repository and a path dependency
of most games:

```toml
[dependencies]
macroquad-toolkit = { path = "../macroquad-toolkit" }
```

It owns reusable cross-game behavior: input and hit testing, UI widgets and text
layout, assets, data loading, camera helpers, events, colors, sprites, saves,
audio, seeded randomness, pathfinding, capture support, and browser/platform
bridges. Projects own their domain models, typed JSON schemas, validation,
simulation rules, screens, and game-specific presentation.

When a game needs a missing generic capability, discuss putting it in the
toolkit. A toolkit change affects every local consumer immediately because it is
a path dependency, so validate both the toolkit and at least one affected game.

## Typical game shape

```text
<game>/
├── Cargo.toml
├── publish.ps1
├── game_page.json
├── catalog_thumbnail.png
├── asset_registry.json          optional selective packaging
├── assets/                      JSON, textures, audio, fonts
├── docs/verification/           accepted UI captures
├── scripts/capture_ui.ps1       optional game wrapper
├── src/
│   ├── main.rs                  Macroquad entry point and frame loop
│   ├── game.rs                  state ownership/transitions
│   ├── data.rs + data/          typed content and loading
│   ├── state.rs + state/        current/persistent state
│   ├── simulation.rs + ...      deterministic domain services
│   └── ui.rs + ui/              drawing and returned intents
└── tests/                       integration/standards tests
```

Match the existing game before imposing this exact skeleton; mature games vary.

## Runtime flow

The usual frame is:

```text
capture input -> active state update -> return intent/transition
              -> apply mutation centrally -> draw current state -> next frame
```

Only one `GameState` variant is active. UI reads state and returns a `UiAction`
or similar intent. The game/state dispatcher applies it. This keeps rendering
testable and prevents hidden mutation through widget callbacks.

## Data and persistence

- Put authored content and tuning in JSON, not large Rust constant tables.
- Define typed project schemas and project-specific validation in the game.
- Use `macroquad_toolkit::data_loader` for embedded/runtime JSON loading and
  platform/error handling.
- Use toolkit persistence so native and browser saves share the supported
  abstraction. The web shell loads the canonical `storage.js` bridge.
- Check the existing game's migration/versioning strategy before changing a
  save schema.

## Display and input rules

Macroquad screen and mouse coordinates are logical pixels, but GPU viewports use
physical framebuffer pixels. Use `VirtualUi::viewport()` or
`macroquad_toolkit::ui::logical_viewport()` at that boundary; do not put
`screen_width()` directly in a camera viewport.

UI text is box-bounded. Use toolkit wrapping, fitting, centering, or truncation
helpers so longer values cannot overlap nearby controls.

Browser games are touch-first. Every tutorial and recovery path must name and
expose a tappable control or explicit gesture.

## Before changing the toolkit

1. Search current toolkit APIs and [../MACROQUAD_TOOLKIT.md](../MACROQUAD_TOOLKIT.md).
2. Confirm the need is cross-game rather than domain-specific.
3. Keep the public API small and consistent with established modules.
4. Add toolkit tests/examples where appropriate.
5. Run toolkit formatting, tests, and clippy.
6. Run tests and `publish.ps1` in an affected game.
7. Commit/push the toolkit change before a game change that depends on it.
8. Explain the required toolkit commit/branch in the game pull request.

Do not convert the path dependency to a registry or Git dependency without an
explicit catalog-wide migration plan.
