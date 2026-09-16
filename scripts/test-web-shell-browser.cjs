// Run test-web-shell.ps1 first. Uses local artifacts and a mocked report API;
// no report is sent and no page is uploaded.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');

const workspace = path.resolve(__dirname, '../..');
const fixtures = path.resolve(process.argv[2] || path.join(workspace, 'publish-logs/web-shell-tests'));
const web = path.join(__dirname, '../web');
const verification = path.join(__dirname, '../docs/verification');
fs.mkdirSync(verification, { recursive: true });
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png' };

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/itch-host.html') {
    res.setHeader('Content-Type', 'text/html');
    res.end('<!doctype html><style>html,body{margin:0;width:100%;height:100%;overflow:hidden}iframe{width:100%;height:100%;border:0;display:block}</style><iframe src="/package/idle_hands/index.html" allow="fullscreen; autoplay" allowfullscreen></iframe>');
    return;
  }
  if (url.pathname === '/project_roost/api/v1/bug-reports/challenge') {
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ success: true, data: { challenge: 'local-test' } }));
    return;
  }
  const parts = decodeURIComponent(url.pathname).split('/').filter(Boolean);
  if (parts.some(p => p === '..' || p.includes('\\'))) { res.writeHead(400).end(); return; }
  if (!path.extname(parts.at(-1) || '')) parts.push('index.html');
  const [, game, ...asset] = parts;
  if (parts[0] === 'package') {
    const file = path.join(workspace, game, 'dist/itch-webgl', ...asset);
    if (!fs.existsSync(file) || !fs.statSync(file).isFile()) { res.writeHead(404).end(); return; }
    res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
    fs.createReadStream(file).pipe(res);
    return;
  }
  const candidates = [path.join(fixtures, ...parts)];
  if (['shared.css', 'bug-report.css', 'bug-report.js'].includes(game)) candidates.push(path.join(web, game));
  if (game === 'shared-assets') candidates.push(path.join(workspace, 'Release', game, ...asset));
  if (asset.length) candidates.push(path.join(workspace, game, 'dist/webgl', ...asset));
  // Itch references assets from its own root.
  if (asset[0] === 'shared-assets') candidates.push(path.join(workspace, 'Release', ...asset));
  if (asset[0] === 'shared.css') candidates.push(path.join(web, 'shared.css'));
  const file = candidates.find(p => fs.existsSync(p) && fs.statSync(p).isFile());
  if (!file) { res.writeHead(404).end(url.pathname); return; }
  res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});

(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.route('https://storage.ko-fi.com/**', route => route.fulfill({ contentType: 'text/javascript', body: 'window.kofiWidgetOverlay = { draw: function () {} };' }));
    await page.goto(`${base}/webhatchery/idle_hands/`);
    await page.waitForFunction(() => !!window.wasm_exports, { timeout: 30000 });
    await page.locator('#loading').waitFor({ state: 'hidden' });
    await page.locator('#glcanvas').click();
    await page.locator('.roost-br-trigger').click();
    const summary = page.locator('#roost-br-summary');
    await summary.click();
    await page.keyboard.type('Typing without holding the mouse');
    await page.waitForTimeout(150);
    assert.equal(await summary.inputValue(), 'Typing without holding the mouse');
    assert.equal(await summary.evaluate(el => document.activeElement === el), true);
    await page.keyboard.press('ArrowLeft');
    await page.keyboard.press('Space');
    assert.equal(await summary.evaluate(el => document.activeElement === el), true);
    const description = page.locator('#roost-br-desc');
    await description.click();
    await page.keyboard.type('First line');
    await page.keyboard.press('Enter');
    await page.keyboard.type('Second line');
    assert.equal(await description.inputValue(), 'First line\nSecond line');
    const contact = page.locator('#roost-br-contact');
    await contact.click();
    await page.keyboard.type('player@example.test');
    assert.equal(await contact.inputValue(), 'player@example.test');
    await page.locator('.roost-br-submit').focus();
    await page.keyboard.press('Tab');
    assert.equal(await page.locator('.roost-br-close').evaluate(el => document.activeElement === el), true);
    await page.keyboard.press('Shift+Tab');
    assert.equal(await page.locator('.roost-br-submit').evaluate(el => document.activeElement === el), true);
    await page.screenshot({ path: path.join(verification, 'web-shell-bug-report.png') });
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('.roost-br-trigger').evaluate(el => document.activeElement === el), true);
    await page.locator('#glcanvas').click();
    assert.equal(await page.locator('#glcanvas').evaluate(el => document.activeElement === el), true);
    // The independently cached widget also works on old global-focus pages.
    await page.evaluate(() => window.addEventListener('click', () => document.getElementById('glcanvas').focus()));
    await page.locator('.roost-br-trigger').click();
    await description.click();
    await page.keyboard.type(' Still focused.');
    assert.equal(await description.inputValue(), 'First line\nSecond line Still focused.');
    await page.keyboard.press('Escape');
    assert.deepEqual(errors, [], 'WebHatchery runtime errors');

    const itch = await browser.newPage({ viewport: { width: 960, height: 540 } });
    const itchErrors = [];
    const external = [];
    const failed = [];
    itch.on('pageerror', error => itchErrors.push(error.message));
    itch.on('request', request => { if (!request.url().startsWith(base)) external.push(request.url()); });
    itch.on('response', response => { if (response.status() >= 400) failed.push(response.url()); });
    await itch.goto(`${base}/itch-host.html`);
    const frame = itch.frames().find(frame => frame.url().includes('/package/'));
    await frame.waitForFunction(() => !!window.wasm_exports, { timeout: 30000 });
    await frame.locator('#loading').waitFor({ state: 'hidden' });
    assert.equal(await frame.locator('.game-info, .roost-br-trigger, #roost-bug-report').count(), 0);
    for (const size of [{ width: 960, height: 540 }, { width: 390, height: 844 }]) {
      await itch.setViewportSize(size);
      const box = await frame.locator('#glcanvas').boundingBox();
      assert.equal(box.width, size.width);
      assert.equal(box.height, size.height);
      assert.equal(box.x, 0);
      assert.equal(box.y, 0);
    }
    await itch.screenshot({ path: path.join(verification, 'web-shell-itch-mobile.png') });
    assert.deepEqual(itchErrors, [], 'Itch runtime errors');
    assert.deepEqual(external, [], 'Itch must load without external site widgets');
    assert.deepEqual(failed, [], 'Standalone itch package must contain every requested asset');
    console.log('Browser checks passed: real Idle Hands WASM, form typing/focus, keyboard navigation, cached-page compatibility, desktop/mobile itch sizing.');
  } finally {
    await browser.close();
    server.close();
  }
})().catch(error => { console.error(error); server.close(); process.exitCode = 1; });
