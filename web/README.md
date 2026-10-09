# Shared web shell

Every game's `index.html` is **generated at publish time** from one canonical
template plus a small per-game data file. There is no hand-maintained
`index.html` or `itch-index.html` in any game directory — the publisher renders
the correct platform variant from the shared template. This stops copies from
drifting apart (which is how 18 games ended up silently losing every web save:
they never loaded `storage.js` at all).

## Files here

| File | Purpose |
|---|---|
| `index.template.html` | The single page shell. `{{PLACEHOLDER}}` tokens are substituted by `publish.ps1`. |
| `storage.js` | Canonical localStorage bridge for `macroquad-toolkit` persistence. Deployed to `shared-assets/runtime/storage.js` and shared by every game. |
| `clipboard.js` | Canonical `clipboard_write_text_extern` bridge (copy-to-clipboard, with a fallback panel when the browser blocks it). Inert for games that never call it. |

`mq_js_bundle.js` is copied from the exact Macroquad version resolved in the
workspace lockfile, including Macroquad's audio and utility plugins.
`sapp_jsutils.js` is downloaded into `shared-assets/runtime/` by `publish.ps1`;
`storage.js` sits alongside them and is referenced the same way. Generated pages
use the Macroquad bundle's content hash as their default runtime cache key, so a
shared runtime repair reaches browsers that have visited a game before.

## Indexed save storage

The shared storage bridge retains its legacy imports and adds checked reads and
removal plus an exclusive writer-lease API for toolkit indexed catalogues. Checked
reads distinguish missing keys from blocked storage; removal failures reach the
game. Writer acquisition uses real Web Locks across tabs and requires HTTPS or
trusted localhost. An unavailable lock manager is an explicit error, never a
localStorage mutex fallback. The lease is released when its Rust store is dropped
or the owning document closes.

Protocol verification is independent of game UI and player storage:

```powershell
node --test .\scripts\test-storage-bridge.cjs
node .\scripts\test-storage-bridge-browser.cjs
```

The first command injects read/write/remove failures and lock contention in
memory. The second uses blank loopback documents in an isolated Chromium context
to verify cross-tab exclusion, reload/close lease release, twelve stored payloads,
and quota/read/remove failures. It creates no screenshots or fixture files.
Publish the consuming game normally to deploy the updated content-hashed bridge;
its visible save/load/retry controls still require the game's own UI review.

## Per-game data file: `game_page.json`

Lives at the root of each game directory. Only `title` is required; everything
else has a default derived from the directory name.

```jsonc
{
  "title": "Dragon's Den",          // <h1> and <title>; may differ from the dir name
  "wasm": "dragons_den",            // default: dir name
  // Project Roost slug is derived globally as "rust_" + dir name.
  "status": { "text": "Playable", "class": "playable" },  // class: playable | in-development
  "controls_hint": "Click the game canvas to start",
  "canvas_rendering": "pixelated",  // pixelated | auto
  "canvas": { "width": 1280, "height": 720 },   // omit to leave the canvas unsized

  "about": ["<p> inner HTML, one entry per paragraph"],

  "controls": [ { "key": "Mouse", "desc": "Click the hoard, buy upgrades" } ],

  "extra_sections": [               // optional info-sections after About/Controls
    { "heading": "Features", "body": "raw inner HTML" }
  ],

  "details": [ { "label": "Genre", "value": "Idle / Incremental" } ],

  "download": { "href": "dragons_den_windows.zip", "label": "Windows Build" },

  // Public source repository. Renders a "Source" sidebar button with the GitHub
  // mark. Omit it when the repo is private — the link would 404 for players.
  // The repo name often differs from the directory name, so read it from the
  // game's own remote rather than deriving it:
  //   cd <game> && git remote get-url origin
  //   gh repo list <owner> --json name,visibility   # check it is PUBLIC first
  "repository": "https://github.com/Kalaith/dragons_den_rust",

  "wasm_cache_bust": null,          // null | "date-now" | literal string
  "asset_cache_bust": null,         // null = runtime hash; literal overrides ?v=
  "storage_js": "shared"            // "shared" | "custom" (use the game's own storage.js)
}
```

### Pointer lock (first-person games)

Browsers only grant pointer lock from a user gesture, so a `set_cursor_grab()`
call from the wasm frame loop is rejected. The template requests it on
`mousedown` instead, for games that opt in:

```jsonc
"pointer_lock": {
  "logical_width": 1280,
  "logical_height": 720,
  "blocked_regions": [           // HUD rects that stay clickable
    { "x": 18, "y": 16, "w": 1244, "h": 64 }
  ]
}
```

Omit the key for every game that is not first-person.

### No per-game CSS or JS

There is deliberately no escape hatch. Every game gets the same shell, and the
shell already handles what games used to hand-roll: canvas focus-on-click,
context-menu suppression, arrow/space scroll prevention, fullscreen resync, DPI
resync, the storage bridge, and the clipboard bridge.

If a game needs behaviour the shell doesn't provide, add it to the template (so
every game gets it) or express it as data in `game_page.json` — don't
reintroduce a per-game file. Presentation belongs in `shared.css`.

## Changing the shell

Edit `index.template.html`, then republish the games. Never edit a generated
`index.html` in a deploy root or a `dist/webgl/` package — it is overwritten on
the next publish.

## Platform variants

`New-RustGameIndexHtml -Platform webhatchery` is the ordinary publisher's default.
It shows the title, About, controls, details, downloads, source link, bug report,
and donations. Legacy `layout: viewport` metadata is ignored so every website
page exposes these details. Players can still choose Play full screen.

`publish-itch.ps1` renders `-Platform itch` directly from the same template and
metadata into `dist/itch-webgl/index.html`. It fills the iframe and omits all
WebHatchery-only blocks before rendering. No bug-report code, donation scripts,
site navigation, descriptions, or Windows downloads are included. Runtime and
stylesheet paths are localized into the package, which is checked against
[itch's HTML5 requirements](https://itch.io/docs/creators/html5).
Upload `dist/itch-webgl` with Butler, never the WebHatchery ZIP. Configure itch's
own fullscreen button and keep descriptions/downloads on the itch project page.
Demo wrappers select a demo WASM; they do not own a separate HTML launcher.

After a shell-only change, refresh existing local packages without compiling or
uploading (including WebHatchery ZIP entry points and existing itch demo pages):

```powershell
.\scripts\refresh-web-shell.ps1                 # all games
.\scripts\refresh-web-shell.ps1 -Project idle_hands
.\scripts\test-web-shell.ps1                    # both variants for every game
node .\scripts\test-web-shell-browser.cjs        # requires Playwright + Chromium
```

The refresh preserves each package's existing WASM. Normal publishing is still
required to deploy refreshed pages to a server or upload them to itch.
Bug-report CSS and JS have content-based cache versions. Canvas focus belongs
only to canvas clicks and explicit play controls; dialog clicks and keystrokes
must never reach the game's global input handlers.
