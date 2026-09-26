// Checked storage and writer leases without touching browser/player storage.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const source = fs.readFileSync(path.join(__dirname, '../web/storage.js'), 'utf8');
const tick = () => new Promise(resolve => setImmediate(resolve));

function harness(options = {}) {
  const values = new Map();
  const failures = { read: false, write: false, remove: false };
  const locks = new Map();
  const context = {
    console: { error() {} },
    consume_js_object: value => value,
    js_object: value => value,
    miniquad_add_plugin(plugin) { this.plugin = plugin; },
    localStorage: {
      getItem(key) {
        if (failures.read) throw new Error('read blocked');
        return values.has(key) ? values.get(key) : null;
      },
      setItem(key, value) {
        if (failures.write) throw new Error('quota exceeded');
        values.set(key, value);
      },
      removeItem(key) {
        if (failures.remove) throw new Error('removal blocked');
        values.delete(key);
      },
    },
    navigator: options.unavailable ? {} : {
      locks: {
        request(name, settings, callback) {
          assert.equal(settings.mode, 'exclusive');
          assert.equal(settings.ifAvailable, true);
          return Promise.resolve().then(() => {
            if (locks.has(name)) return callback(null);
            const lease = {};
            locks.set(name, lease);
            return Promise.resolve(callback(lease)).finally(() => {
              if (locks.get(name) === lease) locks.delete(name);
            });
          });
        },
      },
    },
  };
  vm.createContext(context);
  vm.runInContext(source, context, { filename: 'storage.js' });
  const imports = { env: {} };
  context.storage_plugin.register_plugin(imports);
  return { api: imports.env, values, failures, locks };
}

const poll = (api, id) => JSON.parse(api.storage_lock_poll_extern(id));

test('checked reads distinguish absence, empty payload, and access failure', () => {
  const { api, values, failures } = harness();
  assert.deepEqual(JSON.parse(api.storage_read_checked_extern('save')), { value: null, error: null });
  values.set('save', '');
  assert.deepEqual(JSON.parse(api.storage_read_checked_extern('save')), { value: '', error: null });
  failures.read = true;
  assert.match(JSON.parse(api.storage_read_checked_extern('save')).error, /read blocked/);
  assert.equal(values.get('save'), '');
});

test('quota and removal failures preserve bytes and remain observable', () => {
  const { api, values, failures } = harness();
  assert.equal(api.storage_set_extern('save', 'old'), true);
  failures.write = true;
  assert.equal(api.storage_set_extern('save', 'new'), false);
  assert.equal(values.get('save'), 'old');
  failures.remove = true;
  assert.match(JSON.parse(api.storage_remove_checked_extern('save')).error, /removal blocked/);
  assert.equal(values.get('save'), 'old');
  failures.remove = false;
  assert.equal(JSON.parse(api.storage_remove_checked_extern('save')).error, null);
  assert.equal(JSON.parse(api.storage_remove_checked_extern('save')).error, null);
  assert.equal(values.has('save'), false);
});

test('exclusive leases reject another writer and release for explicit retry', async () => {
  const { api } = harness();
  const first = api.storage_lock_request_extern('macroquad:game:catalogue');
  const second = api.storage_lock_request_extern('macroquad:game:catalogue');
  assert.equal(poll(api, first).status, 'pending');
  await tick();
  assert.equal(poll(api, first).status, 'ready');
  assert.equal(poll(api, second).status, 'busy');
  api.storage_lock_release_extern(first);
  api.storage_lock_release_extern(second);
  await tick();
  const retry = api.storage_lock_request_extern('macroquad:game:catalogue');
  await tick();
  assert.equal(poll(api, retry).status, 'ready');
  api.storage_lock_release_extern(retry);
});

test('dropping an acquisition before its callback cannot orphan a lease', async () => {
  const { api, locks } = harness();
  const dropped = api.storage_lock_request_extern('macroquad:game:catalogue');
  api.storage_lock_release_extern(dropped);
  await tick();
  assert.equal(locks.size, 0);
  assert.equal(poll(api, dropped).status, 'error');
  const next = api.storage_lock_request_extern('macroquad:game:catalogue');
  await tick();
  assert.equal(poll(api, next).status, 'ready');
  api.storage_lock_release_extern(next);
});

test('unavailable locking fails explicitly while legacy symbols stay compatible', () => {
  const { api } = harness({ unavailable: true });
  const id = api.storage_lock_request_extern('macroquad:game:catalogue');
  assert.equal(poll(api, id).status, 'error');
  assert.match(poll(api, id).error, /Web Locks/);
  assert.equal(api.storage_exists_extern('legacy'), false);
  assert.equal(api.storage_get_extern('legacy'), -1);
  assert.equal(api.storage_set_extern('legacy', 'exact bytes'), true);
  assert.equal(api.storage_get_extern('legacy'), 'exact bytes');
  api.storage_remove_extern('legacy');
  assert.equal(api.storage_exists_extern('legacy'), false);
  api.storage_lock_release_extern(id);
});
