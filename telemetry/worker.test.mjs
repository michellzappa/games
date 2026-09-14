import assert from "node:assert/strict";
import worker from "./worker.js";

const originalFetch = globalThis.fetch;
let emailRequest;

try {
  globalThis.fetch = async (url, options) => {
    emailRequest = { url, options };
    return new Response(JSON.stringify({ id: "test-email" }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  };

  const response = await worker.fetch(
    new Request("https://example.test/v1/feedback", {
      method: "POST",
      headers: {
        "content-type": "application/json",
      },
      body: JSON.stringify({
        schema: 1,
        product: "est",
        message: "Please make the cards a little larger.",
        app: {
          version: "1.0.0",
          build: "103",
          ios_major: 26,
          device_family: "iphone",
        },
      }),
    }),
    {
      RESEND_API_KEY: "test-key",
      FEEDBACK_FROM_EMAIL: "feedback@example.test",
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { ok: true });
  assert.equal(emailRequest.url, "https://api.resend.com/emails");
  const email = JSON.parse(emailRequest.options.body);
  assert.deepEqual(email.to, ["mz@centaur-labs.io"]);
  assert.match(email.text, /Please make the cards a little larger\./);

  const invalidResponse = await worker.fetch(
    new Request("https://example.test/v1/feedback", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ schema: 1, product: "est", message: "" }),
    }),
    {},
  );
  assert.equal(invalidResponse.status, 400);
} finally {
  globalThis.fetch = originalFetch;
}

// A fake D1 binding that records the bound values and returns one row set.
function fakeDB(rows = []) {
  const calls = [];
  return {
    calls,
    prepare(sql) {
      return {
        bind(...values) {
          calls.push({ sql, values });
          return {
            async run() { return { success: true }; },
            async all() { return { results: rows }; },
          };
        },
        async all() { calls.push({ sql, values: [] }); return { results: rows }; },
        async run() { calls.push({ sql, values: [] }); return { success: true }; },
      };
    },
  };
}

function batch(product, activity) {
  return {
    schema: 1,
    product,
    batch_id: "b-1",
    period: "2026-W37",
    dedupe_key: "a".repeat(64),
    cohort: "new",
    app: { version: "1.0.0", build: "157", ios_major: 26, device_family: "iphone" },
    activity,
    features: { haptics_enabled: true, immersive_game_mode: true },
  };
}

async function post(path, body, env) {
  return worker.fetch(
    new Request(`https://example.test${path}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
    }),
    env,
  );
}

{
  const db = fakeDB();
  const response = await post("/v1/batches",
    batch("seep", { launches: 3, levels_completed: 5, sets_found: 9 }), { DB: db });
  assert.equal(response.status, 200);
  const stored = JSON.parse(db.calls[0].values.at(-1));
  assert.equal(db.calls[0].values[2], "seep");
  assert.equal(stored.product, "seep");
  // EST-only keys are dropped from a SEEP batch, core keys are kept.
  assert.deepEqual(stored.activity, { launches: 3, levels_completed: 5 });
  assert.deepEqual(stored.features, { haptics_enabled: true });
}

{
  const db = fakeDB();
  const response = await post("/v1/batches",
    batch("est", { launches: 1, sets_found: 9 }), { DB: db });
  assert.equal(response.status, 200);
  const stored = JSON.parse(db.calls[0].values.at(-1));
  assert.deepEqual(stored.activity, { launches: 1, sets_found: 9 });
  assert.deepEqual(stored.features, { haptics_enabled: true, immersive_game_mode: true });
}

{
  const response = await post("/v1/batches", batch("flood", { launches: 1 }), { DB: fakeDB() });
  assert.equal(response.status, 400);
}

{
  const rows = [{ period: "2026-W37", payload: JSON.stringify(
    batch("seep", { games_started: 4, games_completed: 2, levels_completed: 7 })) }];
  const db = fakeDB(rows);
  const response = await worker.fetch(
    new Request("https://example.test/v1/community?product=seep"), { DB: db });
  assert.equal(response.status, 200);
  const stats = await response.json();
  assert.equal(stats.product, "seep");
  assert.equal(db.calls[0].values[0], "seep");
  assert.deepEqual(stats.latest.activity,
    { games_started: 4, games_completed: 2, levels_completed: 7 });
  assert.deepEqual(stats.latest.modes, []);

  // No product parameter is the 1.0.0 EST client.
  const legacy = await worker.fetch(
    new Request("https://example.test/v1/community"), { DB: fakeDB() });
  assert.equal((await legacy.json()).product, "est");

  const unknown = await worker.fetch(
    new Request("https://example.test/v1/community?product=flood"), { DB: fakeDB() });
  assert.equal(unknown.status, 404);
}

console.log("feedback and multi-product worker tests passed");
