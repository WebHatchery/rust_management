# Rust Game Asset Registry

Each game can place an `asset_registry.json` at its project root to define the
exact external asset files included in Windows and WebGL packages. The shared
publisher copies only these files and preserves their project-relative paths.

```json
{
  "version": 1,
  "assets": [
    "assets/images/title.png",
    "assets/audio/click.wav"
  ]
}
```

Registry entries are exact files, not directories or glob patterns. Every path
must be below the project's `assets/` directory. Publishing fails when the JSON
is invalid, the version is unsupported, an entry is duplicated, a path is
unsafe, or a registered file is missing.

Only files loaded externally at runtime belong in the registry. Assets embedded
with `include_str!` or `include_bytes!`, source artwork, contact sheets, editor
metadata, and verification images should remain in the repository but should
not be registered unless the running game actually requests them.

Projects without a registry continue to package their complete `assets/`
directory and emit a warning during the migration period. Once every live game
has a registry, that fallback can be changed to a publishing error.

`asset_packs.json` remains an optional, separate transport step. It operates on
the filtered staging tree produced by the registry. A game must explicitly load
the resulting ZIP through `macroquad-toolkit`; do not enable a pack for code
that requests loose files directly.
