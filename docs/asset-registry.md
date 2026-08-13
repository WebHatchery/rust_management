# Rust Game Asset Registry

Each game can place an `asset_registry.json` at its project root to define the
exact files below `assets/` included in Windows and WebGL packages. The shared
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

The registry controls the packaged `assets/` tree only. The generated web page,
WASM or executable, catalog thumbnail, shared browser runtime, and Windows
download are managed separately by the publisher.

## Confirm The Project Before Editing

Resolve the repository before auditing or changing files:

```powershell
git rev-parse --show-toplevel
Split-Path (Get-Location) -Leaf
cargo metadata --no-deps --format-version 1
```

The repository directory and root Cargo package must match the project named in
the request. Stop if they do not. Do not infer the target from a nearby game or
from a similarly named directory.

## Audit The Runtime Asset Set

Search the whole project before writing the registry. At minimum, inspect:

- direct `load_texture`, `load_sound`, `load_file`, and `load_string` calls;
- toolkit `AssetManager`, `TextureConfig`, `AssetPack`, and `load_asset_pack`
  calls;
- paths inside texture, audio, level, or other runtime data manifests;
- `include_str!`, `include_bytes!`, `include_json_str!`, and other embedded
  data, which do not need external packaged copies;
- dynamically constructed paths, not only quoted `assets/...` strings.

Classify every source file as externally loaded, embedded, development-only, or
unused. Register only the externally loaded files. Exact entries are deliberate:
directories and globs make it too easy for source art and stale derivatives to
return to packages unnoticed.

When runtime paths also live in another manifest or in Rust constants, add a
game-level integrity test that compares that runtime set with
`asset_registry.json`. The publisher proves registered files exist; it cannot
discover a runtime path that the registry forgot.

## Loose Files And Asset Packs

Loose-file loading is the default. Keep the paths requested by the game exactly
the same as their registered project-relative paths.

`asset_packs.json` is an optional, separate transport step. It operates on the
filtered staging tree produced by the registry. A game using a pack must load
the resulting ZIP through `macroquad-toolkit`, and ZIP entries must match the
paths requested at runtime. A game requesting loose files must not delete those
files into a pack it never loads.

Keep both sides synchronized:

- when adding a pack, add and error-check the corresponding runtime pack load;
- when removing a pack, remove the obsolete runtime `load_asset_pack` call;
- never discard a pack-loading error with `let _ = ...` when textures or audio
  depend on that pack.

For a game with no external runtime assets, use an empty registry:

```json
{
  "version": 1,
  "assets": []
}
```

Also remove stale `asset_packs.json` configuration and runtime pack-loading
calls. Embedded source data may remain under `assets/` without being shipped.
Deleting the pack configuration removes the publisher's record of its old
output name, so inspect existing preview and production deployments for a stale
ZIP and remove it during the authorized deployment. Re-publishing alone does
not currently delete an output from a pack configuration that no longer exists.

## Validate A Migration

Run the project's required publisher from the verified game directory:

```powershell
.\publish.ps1
```

Then inspect the generated artifacts rather than treating a successful build as
proof of asset completeness:

1. Compare `dist/webgl/assets/` with the registry for loose-file games.
2. For packed games, list `dist/webgl/*.zip` entries and compare them with the
   registry, including the expected `entry_root`.
3. List the assets inside `dist/*_windows.zip` and perform the same comparison.
4. Confirm removed packs and unregistered assets are absent, including from the
   deployed preview tree.
5. Run the game-level registry/runtime integrity test and the project's normal
   test suite.

If asset-loading errors are recoverable or ignored at runtime, add an explicit
smoke test or capture that exercises the registered assets. A publisher can
successfully package an incomplete registry because it does not execute every
runtime loading path.

Report the source asset count and bytes, the packaged asset count and bytes,
whether a pack was produced, and the exact validation commands used.

Projects without a registry continue to package their complete `assets/`
directory and emit a warning during the migration period. Once every live game
has a registry, that fallback can be changed to a publishing error.
