# itch.io Publishing for RustGames

The itch.io workflow is deliberately separate from the WebHatchery catalog
publisher. `publish.ps1` builds and deploys the catalog; `publish-itch.ps1`
stages its generated artifacts and sends explicit Butler channel uploads. This
keeps an itch release from changing preview/production files or the catalog
index.

## What went wrong

The normal RustGames catalog deployment and an itch.io HTML5 upload have
different filesystem layouts. The catalog page can resolve shared files through
parent paths such as `../shared.css` and `../shared-assets/runtime/...`; an itch
channel is a standalone package root, so those paths produce an unstyled page
or a blank canvas.

The game itself loaded its textures from `assets.zip`, but its loader tried
`.jpg` before `.png` for every texture. PNG-only files therefore generated 404s
for the missing JPEG path before the PNG path succeeded. The archive was valid;
the extension probing order was noisy and misleading.

Finally, browser console URLs are useful release evidence. When the URL still
contains an older itch build ID, the browser is testing a stale upload or cached
embed rather than the latest package.

## Repository layout

The shared implementation is `rust_management/publish-itch.ps1`. The workspace
root `publish-itch.ps1` is a parameter-preserving redirect. Every project has a
small `publish-itch.ps1` wrapper so the command can be run from that project's
base directory. A project that has an itch page stores its target and channels
in `itch.json`:

```json
{
  "target": "kalaith/second-story",
  "channels": {
    "html5": "html5",
    "windows": "windows"
  }
}
```

The `target` is the itch owner/game slug, not the local Rust package name.
Channel names should stay stable across upgrades.

## Reusable rules

1. **Build a self-contained itch package.** Copy the generated WebGL files plus
   every shared stylesheet and runtime bridge into one upload directory. Rewrite
   `index.html` so itch paths are local, for example `shared.css` and
   `shared-assets/runtime/mq_js_bundle.js`, never `../...`.

2. **Keep itch packaging separate from catalog packaging.** The normal
   `dist/webgl` package remains optimized for the WebHatchery catalog. The
   shared `publish-itch.ps1` creates `dist/itch-webgl` and rewrites that copy;
   it never weakens the catalog layout.

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
.\publish-itch.ps1 -DryRun
.\publish-itch.ps1 -Preview
.\publish-itch.ps1 -Status
.\publish-itch.ps1
```

Then check the channel explicitly:

```powershell
butler status <owner>/<game>:html5
butler status <owner>/<game>:windows
```

The dry run validates that `index.html` is at the package root, all local
runtime/WASM/asset references resolve, the Windows download is present when the
page links to it, and the package stays within itch's HTML5 limits. It should
not list sensitive files, project source, or catalog-only assets.

Use `-Channel html5` or `-Channel windows` when releasing only one platform.
Use `-UserVersion <value>` when a human-readable version should be attached to
the Butler build. The normal Butler build number remains automatic. `-Status`
is status-only and never uploads.

## First release setup

For a new itch page, create the page and configure its description, cover art,
tags, and embed dimensions manually. After the first Butler upload, mark the
HTML5 channel as “HTML5 / Playable in browser” and ensure the page kind is
“HTML”. Verify the Windows channel is tagged as Windows. These page settings
are not stored in the repository.

For upgrades, always push to the same configured channel. Butler retains the
channel history and uploads a patch; creating a new channel creates another
download slot instead of upgrading the existing one. Keep old legacy web-upload
files hidden or remove them after the channel build has been verified.
