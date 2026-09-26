// Real Chromium Web Locks/localStorage acceptance in an isolated browser context.
// Serves only in-memory HTML and the canonical bridge; creates no fixture files.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');
const bridge = fs.readFileSync(path.join(__dirname, '../web/storage.js'), 'utf8');
const server = http.createServer((request, response) => {
  response.setHeader('Content-Type', 'text/html');
  response.end(`<!doctype html><meta charset="utf-8"><script>
    var consume_js_object = value => value;
    var js_object = value => value;
    var miniquad_add_plugin = () => {};
    ${bridge}
    var imports = { env: {} };
    storage_plugin.register_plugin(imports);
    var api = imports.env;
  </script>`);
});

(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    const first = await context.newPage();
    const second = await context.newPage();
    await Promise.all([first.goto(base), second.goto(base)]);
    await first.evaluate(() => { window.lease = api.storage_lock_request_extern('macroquad:test:catalogue'); });
    await first.waitForFunction(() => JSON.parse(api.storage_lock_poll_extern(lease)).status === 'ready');
    await second.evaluate(() => { window.lease = api.storage_lock_request_extern('macroquad:test:catalogue'); });
    await second.waitForFunction(() => JSON.parse(api.storage_lock_poll_extern(lease)).status === 'busy');
    await first.evaluate(() => {
      for (let index = 0; index < 12; index++) {
        api.storage_set_extern(`mq-indexed:test:catalogue:payload_${index}`, `v2:${index}`);
      }
    });
    await first.reload(); // Closing the document releases its lifetime lease.
    assert.deepEqual(await first.evaluate(() => Array.from({ length: 12 }, (_, index) =>
      JSON.parse(api.storage_read_checked_extern(`mq-indexed:test:catalogue:payload_${index}`)).value)),
    Array.from({ length: 12 }, (_, index) => `v2:${index}`));
    await first.waitForFunction(async () => !(await navigator.locks.query()).held
      .some(lock => lock.name === 'macroquad:test:catalogue'));
    await second.evaluate(() => {
      api.storage_lock_release_extern(lease);
      window.lease = api.storage_lock_request_extern('macroquad:test:catalogue');
    });
    await second.waitForFunction(() => JSON.parse(api.storage_lock_poll_extern(lease)).status === 'ready');
    // Inject quota/read/removal failures only in this isolated context.
    assert.equal(await second.evaluate(() => {
      const previous = Storage.prototype.setItem;
      Storage.prototype.setItem = () => { throw new DOMException('Injected quota', 'QuotaExceededError'); };
      const result = api.storage_set_extern('mq-indexed:test:catalogue:payload_11', 'bad');
      Storage.prototype.setItem = previous;
      return result;
    }), false);
    assert.equal(await second.evaluate(() => JSON.parse(api.storage_read_checked_extern('mq-indexed:test:catalogue:payload_11')).value), 'v2:11');
    const errors = await second.evaluate(() => {
      const get = Storage.prototype.getItem;
      const remove = Storage.prototype.removeItem;
      Storage.prototype.getItem = () => { throw new Error('read blocked'); };
      Storage.prototype.removeItem = () => { throw new Error('removal blocked'); };
      const errors = [JSON.parse(api.storage_read_checked_extern('test')).error,
        JSON.parse(api.storage_remove_checked_extern('test')).error];
      Storage.prototype.getItem = get;
      Storage.prototype.removeItem = remove;
      return errors;
    });
    assert.deepEqual(errors, ['read blocked', 'removal blocked']);
    await second.close();
    await first.waitForFunction(async () => !(await navigator.locks.query()).held
      .some(lock => lock.name === 'macroquad:test:catalogue'));
    await first.evaluate(() => { window.lease = api.storage_lock_request_extern('macroquad:test:catalogue'); });
    await first.waitForFunction(() => JSON.parse(api.storage_lock_poll_extern(lease)).status === 'ready');
    console.log('PASS: real cross-tab exclusion, reload/close release, 12-key reload discovery, quota/read/removal failures.');
  } finally {
    await context.close();
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => { console.error(error); process.exitCode = 1; server.close(); });
