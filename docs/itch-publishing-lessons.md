# Publishing RustGames on itch.io

This is the catalog-wide runbook for first releases and updates. It incorporates
the lessons from publishing Idle Hands, where a successful Butler upload still
required several rounds of page configuration, package changes, and live-browser
diagnosis before the game was genuinely public and playable.

The game-specific release record remains in that game's repository. For example,
Idle Hands documents its demo split and exact verification evidence in
`idle_hands/docs/ITCH_PUBLISHING_GUIDE.md`.

## The release has three separate layers

Treat these as independent gates. Passing one does not prove the next one.

| Layer | Controls | Proven by |
| --- | --- | --- |
| Game artifacts | Cargo features, assets, WASM/native builds | Project tests and `publish.ps1` |
| itch upload | `itch.json`, staging, Butler channels | `publish-itch.ps1 -DryRun` and `-Status` |
| Storefront | Project kind, upload flags, embed, pricing, visibility | Manual edit-page review and public-page playcheck |

Butler uploads files and maintains channel history. It does not make an HTML
upload browser-playable, choose the embed behavior, set the price, or change a
Draft project to Public.

## Decide the product split before building

Write down what each channel contains. Do not let the build process decide this
implicitly.

| Product | Typical channel | Typical access |
| --- | --- | --- |
| Browser build or demo | `html5` or `html5-demo` | Played free in the page |
| Full Windows build | `windows` | Download or pay what you want |

If the browser edition is restricted while Windows is full:

- use a named Cargo feature such as `demo`;
- build it into a separate target directory such as `target-demo`;
- stage it in a separate directory from the normal `dist/webgl` output;
- verify the restriction in the staged browser package;
- verify the Windows archive is still unrestricted; and
- restore normal WebHatchery artifacts even when packaging fails. Use a
  `finally` block when a wrapper temporarily swaps directories.

This separation prevents a demo WASM artifact from contaminating the paid build
or the normal WebHatchery deployment.

## Repository contract

The shared implementation is `rust_management/publish-itch.ps1`. The workspace
root script is a parameter-preserving redirect. Each participating game keeps:

- `publish-itch.ps1`, a small project wrapper;
- `itch.json`, containing only public target/channel/version configuration; and
- optionally `itch-index.html`, when the normal WebHatchery page is not suitable
  inside an itch iframe.

A typical configuration is:

```json
{
  "target": "owner/game-slug",
  "channels": {
    "html5": "html5",
    "windows": "windows"
  },
  "user_version": "1.0.0"
}
```

The target is the public itch owner and project slug, not necessarily the Rust
package name. Keep channel names stable so later pushes update the same download
slots. Butler credentials belong in Butler's local credential store, never in
Git. A logged-in account may publish to another account's project when it has
administrator rights to that project.

Never commit API keys, session credentials, cookies, or secret page URLs.

## First-release storefront setup

Create the itch project before the final upload and record the intended values
in the release issue or game-specific runbook. For the common inline browser
game plus Windows download model, check the following on the itch edit page.

### Project, files, pricing, and visibility

- Kind of project: **HTML**.
- Browser upload: **This file will be played in the browser**.
- Windows upload: **Executable** and **Windows**, not browser-playable.
- Pricing: the approved model, commonly **$0 or donate**.
- Visibility: keep Draft during setup; choose **Public — Anyone can view the
  page** only after the final live check.

Keep browser and Windows uploads separate. An attached ZIP is not automatically
a playable HTML game.

### Recommended inline embed settings

- Run mode: **Embed in page**.
- Size mode: **Manually set size**.
- Width and height: the game's tested logical aspect, commonly **1280 × 720**.
- Mobile friendly: **Enabled**.
- Automatically start on page load: **Disabled**.
- Fullscreen button: **Enabled**.
- Scrollbars: **Disabled**.
- SharedArrayBuffer support: **Disabled**, unless the game has a tested need.
- Orientation: **Default**, unless the game deliberately locks orientation.

Do not select **Click to launch in fullscreen** when the desired experience is
an inline game. That mode replaces the itch page after Run game is clicked.

## Package the game embed, not another storefront

The normal `dist/webgl/index.html` is a complete WebHatchery product page. It
may contain a title, controls, About copy, downloads, footer, donation widget,
bug-report widget, and shared files referenced through `../` paths. Nesting that
page inside itch duplicates the storefront and can break its relative paths.

An itch-specific launcher should contain only what the embedded runtime needs:

- a temporary loading state;
- the canvas;
- required JavaScript/runtime bridges;
- focus, touch, context-menu, and resize behavior; and
- the call that loads the game's WASM module.

The shared publisher copies the package to `dist/itch-webgl`, localizes required
runtime files, rejects missing or parent-relative references, and checks itch's
HTML5 file/path/size limits. A game-specific wrapper may replace the generated
page with `itch-index.html` before shared staging.

For custom launchers:

- make `[hidden]` states explicit in CSS when another display rule could win;
- never have a `resize` listener dispatch the same event it listens to;
- preserve the tested canvas aspect ratio in landscape so pointer coordinates
  match the game's virtual UI; and
- test portrait behavior independently if the game supports it.

## Preflight and upload procedure

Run from the game directory.

### 1. Validate the normal release

```powershell
.\publish.ps1
```

This must produce the intended full Windows archive and normal WebGL package.
Also run any project-specific warnings-as-errors, test, and browser gates.

### 2. Stage without uploading

```powershell
.\publish-itch.ps1 -Channel all -DryRun
```

Confirm the printed target and both channels. Inspect `dist/itch-webgl` and
verify:

- `index.html` is at the package root;
- the WASM, assets, and runtime bridges exist at the paths the page requests;
- no local reference begins with `/` or `../`;
- no source, credentials, catalog-only assets, or unwanted widgets are present;
- the browser build has the intended demo/full content; and
- the Windows ZIP has the intended full/demo content.

`-Preview` asks Butler for a per-file channel diff without uploading. It is
useful after the local package has passed inspection:

```powershell
.\publish-itch.ps1 -Channel all -Preview
```

### 3. Test the exact staged browser package

Do not substitute the normal WebHatchery preview. Serve `dist/itch-webgl` using
the project's shipping-browser harness and exercise at least:

- loading-state removal and first rendered frame;
- touch/click navigation and a complete core interaction;
- audio activation after user input;
- save, reload, and recovery;
- desktop resize, the configured embed size, and supported mobile layouts;
- missing requests, page errors, console errors, WASM panics, and WebGL errors;
- any demo lock or purchase path; and
- a visible return/restart path.

Custom fonts need special attention on WebGL. Unbounded glyph prewarming can
overflow a font atlas; entirely lazy growth can replace a GPU texture while a
frame still references it. If a game uses a custom font, warm a bounded,
representative glyph set at the sizes the interface actually uses before the
first visible UI frame, then keep the console clean while opening later screens.

### 4. Upload explicitly

```powershell
.\publish-itch.ps1 -Channel all
```

Or isolate a platform:

```powershell
.\publish-itch.ps1 -Channel html5
.\publish-itch.ps1 -Channel windows
```

Use `-UserVersion <value>` when attaching a human-readable version. Do not add
itch upload behavior to the ordinary publisher or batch catalog publishers;
external uploads must remain an explicit action.

### 5. Wait for itch processing

```powershell
.\publish-itch.ps1 -Channel html5 -Status
.\publish-itch.ps1 -Channel windows -Status
```

A successful push may still be processing. Wait for the newest build to show as
ready and record its build number. Otherwise a public-page test can accidentally
prove an older cached build.

### 6. Verify the public product

Use a fresh browser tab or session and check the page as a player:

1. The page says **Published**, not Draft or Restricted.
2. **Run game** appears before launch when autostart is disabled.
3. Launch keeps the itch header, description, downloads, and comments visible.
4. The iframe contains the game canvas and loading state, not a second storefront.
5. The game reaches its first interactive screen and touch/click input lands on
   the visible controls.
6. The console and network panel have no panics, `RuntimeError: unreachable`,
   deleted-texture errors, or failed local assets.
7. Logged asset URLs contain the newest processed itch build number.
8. The Windows download has the intended label, platform, and pricing/access.
9. The browser and Windows editions contain the correct demo/full content.

Only after these checks should a first release move from Draft to Public. After
saving visibility, repeat the public URL check in a session that is not relying
on administrator access.

## Fast troubleshooting map

| Symptom | First check |
| --- | --- |
| Upload downloads instead of playing | Project kind and browser-playable upload flag |
| Launch replaces the itch page | Embed mode is fullscreen/maximized instead of inline |
| Duplicate title/About/controls/footer | Packaged `index.html` is the WebHatchery page |
| Blank or black canvas | Console for a WASM panic and the build number in asset URLs |
| Missing style/runtime or 404s | Parent-relative paths or asset-extension probing |
| Deleted WebGL texture errors | Custom font atlas growing during a visible frame |
| Loading text covers the game | A CSS display rule overrides the `hidden` attribute |
| Stack overflow during resize | A resize handler dispatches its own event |
| Touch misses visible controls | Canvas aspect ratio and virtual-UI letterboxing |
| Old behavior after upload | New build is processing or the iframe is cached |
| Admin can view but public cannot | Visibility is Draft or Restricted |
| Browser has full-only content | Demo feature/artifact was not used for HTML5 |
| Windows is unexpectedly restricted | Demo artifact contaminated the normal build path |

## Release record to keep in each game

Record enough detail that the next release does not require rediscovery:

- public itch target and stable channel names;
- what each channel contains and how demo/full separation is enforced;
- approved pricing, visibility, and embed settings;
- exact local validation and shipping-browser commands;
- privacy/analytics state;
- newest verified Butler build numbers and release date;
- public-page verification result; and
- any game-specific launcher, font, resize, input, or asset constraints.

Build numbers are evidence, not configuration. Always validate the newest
processed build reported by Butler.
