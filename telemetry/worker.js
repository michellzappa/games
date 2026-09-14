// Activity and feature keys every game in the library may report.
const CORE_ACTIVITY = [
  "launches", "games_started", "games_completed",
  "hints_used", "tutorial_viewed", "leaderboard_viewed",
];
const CORE_FEATURES = [
  "tutorial_seen", "hints_used", "sound_effects_enabled", "haptics_enabled",
];

// One Worker serves every game. The payload's `product` selects the entry;
// each entry whitelists its own keys and names the totals and modes that
// `GET /v1/community?product=` reports. An unknown product is rejected.
const PRODUCTS = {
  est: {
    label: "EST",
    activity: new Set([
      ...CORE_ACTIVITY,
      "sets_found",
      "full_solo_started", "full_solo_completed",
      "quick_solo_started", "quick_solo_completed",
      "local_duel_started", "local_duel_completed",
      "network_duel_started", "network_duel_completed",
    ]),
    features: new Set([
      ...CORE_FEATURES,
      "quick_solo_used", "local_duel_used", "network_duel_used",
      "immersive_game_mode",
    ]),
    community: {
      totals: ["games_started", "games_completed", "sets_found"],
      modes: [
        { name: "full_solo", key: "full_solo_started" },
        { name: "quick_solo", key: "quick_solo_started" },
        { name: "local_duel", key: "local_duel_started" },
        { name: "network_duel", key: "network_duel_started" },
      ],
    },
  },
  seep: {
    label: "SEEP",
    activity: new Set([
      ...CORE_ACTIVITY,
      "levels_completed", "undos_used",
    ]),
    features: new Set(CORE_FEATURES),
    community: {
      totals: ["games_started", "games_completed", "levels_completed"],
      modes: [],
    },
  },
};
const DEFAULT_PRODUCT = "est";

function productConfig(value) {
  return typeof value === "string" && Object.hasOwn(PRODUCTS, value)
    ? PRODUCTS[value]
    : null;
}

const ALLOWED_COHORTS = new Set(["new", "returning", "reactivated"]);
const ALLOWED_DEVICE_FAMILIES = new Set(["iphone", "ipad"]);
const RETENTION_DAYS = 180;
const FEEDBACK_RECIPIENT = "mz@centaur-labs.io";
const MAX_FEEDBACK_LENGTH = 5000;
const MAX_FEEDBACK_BODY_BYTES = 12000;
// RFC 5321 caps an address at 254 characters.
const MAX_FEEDBACK_EMAIL_LENGTH = 254;
// Keep this at one while the app is being tested so a single install can show
// its aggregate. Raise it before a public release if cohort privacy is needed.
const COMMUNITY_MINIMUM_GROUP_SIZE = 1;
const COMMUNITY_HISTORY_WEEKS = 12;

function json(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...extraHeaders,
    },
  });
}

function boundedString(value, max) {
  return typeof value === "string" && value.length > 0 && value.length <= max
    ? value
    : null;
}

function feedbackMessage(value) {
  if (typeof value !== "string") return null;
  const normalized = value
    .replace(/\r\n?/g, "\n")
    .replace(/[\x00-\x08\x0b-\x1f\x7f]/g, " ")
    .trim();
  return normalized.length > 0 && normalized.length <= MAX_FEEDBACK_LENGTH
    ? normalized
    : null;
}

// Validate the optional reply address at the boundary. An address that fails
// this check is dropped rather than rejecting the whole message: the player
// still deserves to have their feedback delivered.
function feedbackReplyEmail(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > MAX_FEEDBACK_EMAIL_LENGTH) return null;
  return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(trimmed) ? trimmed : null;
}

function sanitizeFeedback(payload) {
  if (!payload || typeof payload !== "object") return null;
  if (payload.schema !== 1 || !productConfig(payload.product)) return null;

  const message = feedbackMessage(payload.message);
  const app = payload.app;
  if (!message || !app || typeof app !== "object") return null;

  const version = boundedString(app.version, 32);
  const build = boundedString(app.build, 64);
  const iosMajor = Number.isInteger(app.ios_major)
      && app.ios_major >= 13 && app.ios_major <= 99
    ? app.ios_major
    : null;
  const deviceFamily = ALLOWED_DEVICE_FAMILIES.has(app.device_family)
    ? app.device_family
    : null;
  if (!version || !build || iosMajor === null || !deviceFamily) return null;

  const safe = {
    product: payload.product,
    message,
    reply_email: feedbackReplyEmail(payload.reply_email),
    app: {
      version,
      build,
      ios_major: iosMajor,
      device_family: deviceFamily,
    },
  };
  return JSON.stringify(safe).length <= MAX_FEEDBACK_BODY_BYTES ? safe : null;
}

async function sendFeedbackEmail(env, feedback) {
  const apiKey = env.RESEND_API_KEY?.trim();
  const from = env.FEEDBACK_FROM_EMAIL?.trim();
  if (!apiKey || !from) {
    console.error("[feedback] missing RESEND_API_KEY or FEEDBACK_FROM_EMAIL");
    return false;
  }

  const { app, message, reply_email: replyEmail } = feedback;
  const label = PRODUCTS[feedback.product].label;
  const text = [
    `New ${label} feedback`,
    "",
    `Version: ${app.version} (build ${app.build})`,
    `iOS: ${app.ios_major}`,
    `Device: ${app.device_family}`,
    `Reply to: ${replyEmail ?? "not provided"}`,
    "",
    "Message:",
    message,
  ].join("\n");

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [FEEDBACK_RECIPIENT],
        // Replying in a mail client then reaches the player directly.
        ...(replyEmail ? { reply_to: [replyEmail] } : {}),
        subject: `[${label} feedback] ${app.version} (${app.build})`,
        text,
      }),
    });
    if (!response.ok) {
      console.error("[feedback] Resend rejected message", response.status);
      return false;
    }
    return true;
  } catch (error) {
    console.error("[feedback] Resend request failed", error);
    return false;
  }
}

function safeActivity(value, allowed) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result = {};
  for (const [key, count] of Object.entries(value)) {
    if (allowed.has(key)
        && Number.isInteger(count) && count >= 0 && count <= 999999) {
      result[key] = count;
    }
  }
  return result;
}

function safeFeatures(value, allowed) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result = {};
  for (const [key, enabled] of Object.entries(value)) {
    if (allowed.has(key) && typeof enabled === "boolean") {
      result[key] = enabled;
    }
  }
  return result;
}

function sanitize(payload) {
  if (!payload || typeof payload !== "object") return null;
  const config = productConfig(payload.product);
  if (payload.schema !== 1 || !config) return null;

  const batchID = boundedString(payload.batch_id, 80);
  const period = boundedString(payload.period, 12);
  const dedupeKey = typeof payload.dedupe_key === "string"
      && /^[0-9a-f]{64}$/.test(payload.dedupe_key)
    ? payload.dedupe_key
    : null;
  const cohort = typeof payload.cohort === "string"
      && ALLOWED_COHORTS.has(payload.cohort)
    ? payload.cohort
    : null;
  const app = payload.app;

  if (!batchID || !period || !dedupeKey
      || !/^\d{4}-W(?:0[1-9]|[1-4]\d|5[0-3])$/.test(period)
      || !app || typeof app !== "object") {
    return null;
  }

  const version = boundedString(app.version, 32);
  const build = boundedString(app.build, 64);
  const iosMajor = Number.isInteger(app.ios_major)
      && app.ios_major >= 13 && app.ios_major <= 99
    ? app.ios_major
    : null;
  const deviceFamily = ALLOWED_DEVICE_FAMILIES.has(app.device_family)
    ? app.device_family
    : null;
  if (!version || !build || iosMajor === null || !deviceFamily) return null;

  const safe = {
    schema: 1,
    product: payload.product,
    batch_id: batchID,
    dedupe_key: dedupeKey,
    period,
    cohort,
    app: {
      version,
      build,
      ios_major: iosMajor,
      device_family: deviceFamily,
    },
    activity: safeActivity(payload.activity, config.activity),
    features: safeFeatures(payload.features, config.features),
  };
  return JSON.stringify(safe).length <= 16384 ? safe : null;
}

function isoWeekPeriod(date) {
  const thursday = new Date(Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
  ));
  const day = thursday.getUTCDay() || 7;
  thursday.setUTCDate(thursday.getUTCDate() + 4 - day);
  const year = thursday.getUTCFullYear();
  const yearStart = new Date(Date.UTC(year, 0, 1));
  const week = Math.ceil(
    (((thursday - yearStart) / 86400000) + 1) / 7,
  );
  return `${year}-W${String(week).padStart(2, "0")}`;
}

function readAggregateRows(result) {
  return (result?.results ?? []).flatMap((row) => {
    try {
      const payload = JSON.parse(row.payload);
      return payload && typeof payload === "object"
        ? [{ period: row.period, payload }]
        : [];
    } catch {
      return [];
    }
  });
}

function activityTotal(rows, key) {
  return rows.reduce(
    (total, row) => total + (Number.isInteger(row.payload.activity?.[key])
      ? row.payload.activity[key]
      : 0),
    0,
  );
}

function visible(value, reportingDevices) {
  return reportingDevices >= COMMUNITY_MINIMUM_GROUP_SIZE ? value : null;
}

function adoptionPercent(rows, key) {
  if (rows.length < COMMUNITY_MINIMUM_GROUP_SIZE) return null;
  const adopters = rows.filter(
    (row) => (row.payload.activity?.[key] ?? 0) > 0,
  ).length;
  return Math.round((adopters / rows.length) * 100);
}

function totals(rows, keys, reportingDevices) {
  return Object.fromEntries(keys.map((key) => [
    key,
    visible(activityTotal(rows, key), reportingDevices),
  ]));
}

async function communityStats(env, product) {
  const config = PRODUCTS[product];
  const result = await env.DB.prepare(
    "SELECT period, payload FROM telemetry_batches WHERE product = ? ORDER BY period"
  ).bind(product).all();
  const rows = readAggregateRows(result);
  const periods = [...new Set(rows.map((row) => row.period))].sort();
  const periodsToShow = periods.slice(-COMMUNITY_HISTORY_WEEKS);
  const currentPeriod = isoWeekPeriod(new Date());

  const weeklyActive = periodsToShow.map((period) => {
    const periodRows = rows.filter((row) => row.period === period);
    return {
      period,
      count: visible(periodRows.length, periodRows.length),
      in_progress: period === currentPeriod,
      ...totals(periodRows, config.community.totals, periodRows.length),
    };
  });

  const latestPeriod = periods.at(-1);
  if (!latestPeriod) {
    return {
      schema: 1,
      product,
      generated_on: new Date().toISOString(),
      privacy: { minimum_group_size: COMMUNITY_MINIMUM_GROUP_SIZE },
      weekly_active: weeklyActive,
      latest: null,
    };
  }

  const latestRows = rows.filter((row) => row.period === latestPeriod);
  const reportingDevices = latestRows.length;
  return {
    schema: 1,
    product,
    generated_on: new Date().toISOString(),
    privacy: { minimum_group_size: COMMUNITY_MINIMUM_GROUP_SIZE },
    weekly_active: weeklyActive,
    latest: {
      period: latestPeriod,
      in_progress: latestPeriod === currentPeriod,
      reporting_devices: visible(reportingDevices, reportingDevices),
      activity: totals(latestRows, config.community.totals, reportingDevices),
      modes: config.community.modes.map(({ name, key }) => ({
        name,
        percent: adoptionPercent(latestRows, key),
      })),
    },
  };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true });
    }
    if (request.method === "GET" && url.pathname === "/v1/community") {
      // The 1.0.0 EST client sends no product; it keeps getting EST.
      const product = url.searchParams.get("product") ?? DEFAULT_PRODUCT;
      if (!productConfig(product)) {
        return json({ error: "unknown_product" }, 404);
      }
      return json(await communityStats(env, product), 200, {
        "access-control-allow-origin": "*",
        "cache-control": "public, max-age=300",
      });
    }
    if (request.method === "POST" && url.pathname === "/v1/feedback") {
      const contentLength = Number(request.headers.get("content-length"));
      if (Number.isFinite(contentLength) && contentLength > MAX_FEEDBACK_BODY_BYTES) {
        return json({ error: "payload_too_large" }, 413);
      }
      if (!request.headers.get("content-type")?.toLowerCase()
          .startsWith("application/json")) {
        return json({ error: "content_type_required" }, 415);
      }

      let payload;
      try {
        payload = await request.json();
      } catch {
        return json({ error: "invalid_json" }, 400);
      }
      const feedback = sanitizeFeedback(payload);
      if (!feedback) return json({ error: "invalid_payload" }, 400);

      if (!await sendFeedbackEmail(env, feedback)) {
        return json({ error: "feedback_unavailable" }, 503);
      }
      return json({ ok: true });
    }
    if (request.method !== "POST" || url.pathname !== "/v1/batches") {
      return json({ error: "method_not_allowed" }, 405);
    }
    if (!request.headers.get("content-type")?.toLowerCase()
        .startsWith("application/json")) {
      return json({ error: "content_type_required" }, 415);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: "invalid_json" }, 400);
    }
    const safe = sanitize(payload);
    if (!safe) return json({ error: "invalid_payload" }, 400);

    const receivedAt = new Date().toISOString();
    await env.DB.prepare(
      `INSERT INTO telemetry_batches
       (batch_id, received_at, product, period, dedupe_key, cohort, app_version,
        app_build, ios_major, device_family, payload)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(product, period, dedupe_key) DO UPDATE SET
         batch_id = excluded.batch_id,
         received_at = excluded.received_at,
         cohort = excluded.cohort,
         app_version = excluded.app_version,
         app_build = excluded.app_build,
         ios_major = excluded.ios_major,
         device_family = excluded.device_family,
         payload = excluded.payload`
    ).bind(
      safe.batch_id,
      receivedAt,
      safe.product,
      safe.period,
      safe.dedupe_key,
      safe.cohort,
      safe.app.version,
      safe.app.build,
      safe.app.ios_major,
      safe.app.device_family,
      JSON.stringify(safe),
    ).run();
    return json({ ok: true });
  },

  async scheduled(_event, env) {
    await env.DB.prepare(
      "DELETE FROM telemetry_batches WHERE received_at < datetime('now', ?)"
    ).bind(`-${RETENTION_DAYS} days`).run();
  },
};
