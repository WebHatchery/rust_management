# itch.io Publishing Lessons for RustGames

This note captures the practical lessons from publishing Apartment Manager as a
Rust + Macroquad WebGL game to itch.io. The recommendations apply to any game
using the shared RustGames web shell and asset-pack workflow.

## What went wrong

The normal RustGames catalog deployment and an itch.io HTML5 upload have
different filesystem layouts. The catalog page can resolve shared files through
parent paths such as `../shared.css` and `../shared-assets/runtime/...`; an itch
channel is a standalone package root, so those paths produce an unstyled page or
a blank canvas.

The game itself loaded its textures from `assets.zip`, but its loader tried
`.jpg` before `.png` for every texture. PNG-only files therefore generated 404s
for the missing JPEG path before the PNG path succeeded. The archive was valid;
the extension probing order was noisy and misleading.

Finally, browser console URLs are useful release evidence. When the URL still
contains an older itch build ID, the browser is testing a stale upload or cached
embed rather than the latest package.

## Reusable rules

1. **Build a self-contained itch package.** Copy the generated WebGL files plus
   every shared stylesheet and runtime bridge into one upload directory. Rewrite
   `index.html` so itch paths are local, for example `shared.css` and
   `shared-assets/runtime/mq_js_bundle.js`, never `../...`.

2. **Keep itch packaging separate from catalog packaging.** The normal
   `dist/webgl` package can remain optimized for the WebHatchery catalog. Use a
   project or shared `publish-itch.ps1` step to create a separate staging
   directory rather than weakening the catalog layout for itch.

3. **Make asset extension selection deterministic.** If the asset pack contains
   both JPEG and PNG files, choose the known extension first for each asset (or
   store the extension in data). Do not probe a missing extension through a
   loose-file fallback, because WebGL turns that probe into a visible 404.

4. **Treat the ZIP as part of the runtime contract.** Verify that the archive
   contains the exact paths requested by the Rust code, such as
   `assets/textures/icon_money.png`. Listing the archive is faster and more
   reliable than inferring its contents from the source directory.

5. **Use explicit itch channels.** Publish the browser package to an `html5`
   channel and the native package to a `windows` channel on the existing game
   page. Keep the previous upload until the replacement has been tested.

6. **Strip platform-specific widgets when appropriate.** Ko-fi, bug-report, or
   catalog-only controls can be removed from the itch-specific HTML package
   without changing the WebHatchery-hosted version.

7. **Verify the live build, not only Butler's upload.** `butler status` confirms
   that itch processed the build, but a fresh browser session should also:

   - click `Run game`;
   - confirm the page is styled and the canvas renders;
   - inspect console errors for 404s and WASM/runtime failures;
   - check that console URLs refer to the newest build ID.

8. **Keep credentials outside the repository.** Authenticate Butler once with
   `butler login`; let it use its local credential file. Never commit an itch API
   key or place it in a project script.

## Recommended release checklist

From the game directory:

```powershell
.\publish.ps1
cargo fmt -- --check
cargo test --bin <game_binary>
.\scripts\publish-itch.ps1 -DryRun
.\scripts\publish-itch.ps1
```

Then check the channel explicitly:

```powershell
butler status <owner>/<game>:html5
butler status <owner>/<game>:windows
```

For the upload script, the dry run should list `index.html`, the WASM file,
`assets.zip`, the local shared runtime files, and any intended download files.
It should not list sensitive files, project source, or catalog-only assets that
are not meant for itch.

## Suggested shared tooling improvement

Every game that publishes to itch should eventually use one shared helper with
these properties:

- takes the project directory and itch target as parameters;
- stages a standalone HTML5 package;
- rewrites catalog-relative paths;
- supports `-DryRun`;
- publishes with Butler and reports the channel/build ID;
- optionally removes catalog-only widgets;
- leaves the ordinary RustGames `publish.ps1` workflow unchanged.

That keeps each game’s release command short while preserving the important
separation between a catalog deployment and an itch.io upload.
