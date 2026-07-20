# Shared web shell

Every game's `index.html` is **generated at publish time** from one canonical
template plus a small per-game data file. There is no hand-maintained
`index.html` in any game directory — `publish.ps1` renders one into the WebGL
package and deploys that. This is what stops the 28 near-identical copies from
drifting apart (which is how 18 games ended up silently losing every web save:
they never loaded `storage.js` at all).

## Files here

| File | Purpose |
|---|---|
| `index.template.html` | The single page shell. `{{PLACEHOLDER}}` tokens are substituted by `publish.ps1`. |
| `storage.js` | Canonical localStorage bridge for `macroquad-toolkit` persistence. Deployed to `shared-assets/runtime/storage.js` and shared by every game. |
| `clipboard.js` | Canonical `clipboard_write_text_extern` bridge (copy-to-clipboard, with a fallback panel when the browser blocks it). Inert for games that never call it. |

`mq_js_bundle.js` and `sapp_jsutils.js` are downloaded into
`shared-assets/runtime/` by `publish.ps1`; `storage.js` now sits alongside them
and is referenced the same way.

## Per-game data file: `game_page.json`

Lives at the root of each game directory. Only `title` is required; everything
else has a default derived from the directory name.

```jsonc
{
  "title": "Dragon's Den",          // <h1> and <title>; may differ from the dir name
  "wasm": "dragons_den",            // default: dir name
  "roost_slug": "rust_dragons_den", // default: "rust_" + dir name
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
  "asset_cache_bust": null,         // ?v= appended to the three runtime script tags
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
