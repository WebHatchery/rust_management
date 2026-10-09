// WASM storage bridge for macroquad-toolkit persistence.
// Loaded after sapp_jsutils.js and before the game wasm.

// Indexed catalogues hold an exclusive Web Lock for the writer's lifetime.
// A promise keeps the lease alive while synchronous WASM storage calls run.
var storage_writer_leases = new Map();
var storage_next_lease = 1;

function storage_error(error) {
    return String(error && error.message ? error.message : error);
}

var storage_plugin = {
    name: "storage",
    version: 1,
    register_plugin: function(importObject) {
        importObject.env.storage_read_checked_extern = function(key_obj) {
            var key = consume_js_object(key_obj);
            try {
                return js_object(JSON.stringify({ value: localStorage.getItem(key), error: null }));
            } catch (error) {
                return js_object(JSON.stringify({ value: null, error: storage_error(error) }));
            }
        };

        importObject.env.storage_remove_checked_extern = function(key_obj) {
            var key = consume_js_object(key_obj);
            try {
                localStorage.removeItem(key);
                return js_object(JSON.stringify({ error: null }));
            } catch (error) {
                return js_object(JSON.stringify({ error: storage_error(error) }));
            }
        };

        importObject.env.storage_lock_request_extern = function(name_obj) {
            var name = consume_js_object(name_obj);
            var id = storage_next_lease++;
            var lease = { status: "pending", error: null, release: null, cancelled: false };
            storage_writer_leases.set(id, lease);
            if (!globalThis.navigator || !navigator.locks) {
                lease.status = "error";
                lease.error = "Safe saving requires Web Locks in a secure browser context (HTTPS).";
                return id;
            }
            try {
                navigator.locks.request(name, { mode: "exclusive", ifAvailable: true }, function(lock) {
                    if (lease.cancelled) return;
                    if (!lock) {
                        lease.status = "busy";
                        return;
                    }
                    lease.status = "ready";
                    return new Promise(function(resolve) { lease.release = resolve; });
                }).catch(function(error) {
                    if (lease.cancelled) return;
                    lease.status = "error";
                    lease.error = storage_error(error);
                });
            } catch (error) {
                lease.status = "error";
                lease.error = storage_error(error);
            }
            return id;
        };

        importObject.env.storage_lock_poll_extern = function(id) {
            var lease = storage_writer_leases.get(id);
            return js_object(JSON.stringify(lease ? { status: lease.status, error: lease.error }
                : { status: "error", error: "The save writer lease has been released." }));
        };

        importObject.env.storage_lock_release_extern = function(id) {
            var lease = storage_writer_leases.get(id);
            if (!lease) return;
            lease.cancelled = true;
            if (lease.release) lease.release();
            storage_writer_leases.delete(id);
        };

        importObject.env.storage_set_extern = function(key_obj, value_obj) {
            var key = consume_js_object(key_obj);
            var value = consume_js_object(value_obj);
            try {
                localStorage.setItem(key, value);
                return true;
            } catch (e) {
                console.error("storage_set failed:", e);
                return false;
            }
        };

        importObject.env.storage_get_extern = function(key_obj) {
            var key = consume_js_object(key_obj);
            try {
                var value = localStorage.getItem(key);
                if (value === null) {
                    return -1;
                }
                return js_object(value);
            } catch (e) {
                console.error("storage_get failed:", e);
                return -1;
            }
        };

        importObject.env.storage_remove_extern = function(key_obj) {
            var key = consume_js_object(key_obj);
            try {
                localStorage.removeItem(key);
            } catch (e) {
                console.error("storage_remove failed:", e);
            }
        };

        importObject.env.storage_exists_extern = function(key_obj) {
            var key = consume_js_object(key_obj);
            try {
                return localStorage.getItem(key) !== null;
            } catch (e) {
                return false;
            }
        };
    }
};

miniquad_add_plugin(storage_plugin);
