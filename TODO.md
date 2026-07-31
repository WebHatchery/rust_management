# TODO — rust_management

Open items left over from the tooling audits, which are otherwise closed out.

## Publish pipeline

- Verify `ai_defense` actually loads its packed assets at runtime. It has an
  `asset_packs.json` declaring `tiles.zip` and `tiles_128.zip`, but there is no
  `load_asset_pack` / `AssetPack` call anywhere in its `src/` — so the packs may
  be published and never read. Don't use it as the reference wiring for another
  game until this is settled.

## macroquad-toolkit

- A configurable input snapshot / keymap helper, so games can keep their own
  action sets while building them on one shared binding layer. It is the last
  unbuilt item from the adoption audit — everything else it asked for (virtual
  UI, tooltips, form widgets, scroll and tabs, settings with volume groups,
  achievements, the debug overlay, raster, capture) has since landed.
