# Telemetry service

This is the small first-party intake for the optional anonymous diagnostics
of every game in this repo. One Worker serves every game: each payload
carries a `product` slug (`est`, `seep`), the `PRODUCTS` table in `worker.js`
whitelists that game's keys, D1 rows carry the product, and
`GET /v1/community?product=<slug>` aggregates one game. A request with no
product parameter is the EST 1.0.0 client and gets EST.

Adding a game: add its entry to `PRODUCTS`, deploy. No schema change.
It also forwards the app's optional free-text feedback form to
`mz@centaur-labs.io`. Feedback is not stored in D1 and does not require
anonymous-diagnostics consent.

The diagnostics side has no accounts, client credentials, public user data, or
stable install identifiers. The Worker stores one aggregate row per app install
per ISO week; the week-scoped dedupe key makes retries and activity refreshes
update that row instead of inflating the period.

## Deploy

The tracked `wrangler.toml` keeps a placeholder database id so the real one
stays out of the public repository. Wrangler refuses to deploy with the
placeholder: "binding DB of type d1 must have a valid `database_id`". Keep the
real id in `telemetry/wrangler.local.toml`, which is gitignored, and deploy
with it:

```bash
npx wrangler deploy --config telemetry/wrangler.local.toml
```

Recreate that file from the tracked one with `npx wrangler d1 list` if it is
missing.

Install Wrangler, create the D1 database, put its id in the local config, then
apply the schema and deploy:

```sh
npx wrangler d1 create est-telemetry
npx wrangler d1 execute est-telemetry --remote --file=schema.sql
npx wrangler deploy
```

For feedback delivery, configure the verified Resend sender before deploying:

```sh
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put FEEDBACK_FROM_EMAIL
```

The first-party EST target uses
`https://est-telemetry.envisioning.workers.dev/v1/batches`. A distributor can
replace the `ESTTelemetryEndpoint` Info.plist build setting with
`https://your-worker.example/v1/batches`, or set the `estTelemetryEndpoint`
UserDefaults key during local testing. Forks should keep diagnostics disabled
unless they have reviewed and configured their own service.

The Worker whitelists every activity and feature key, validates the app
contract, stores no request headers or IP addresses, and prunes raw batches
after 180 days. `GET /v1/community` exposes only privacy-thresholded
activity aggregates for the Settings screen: active devices, games started and
completed, sets found, and mode adoption. The testing configuration shows
values after one device reports during testing. Raise
`COMMUNITY_MINIMUM_GROUP_SIZE` before a public release if cohort privacy is
required. Raw batches and version metadata are never returned by that endpoint.
Because the intake is intentionally
unauthenticated, configure Cloudflare rate limiting or WAF rules before public
deployment and treat the aggregate as approximate.

## Feedback

The app posts JSON to `POST /v1/feedback`. The Worker validates and length-caps
the message, adds the app version/build and coarse device context supplied by
the app, and forwards it through Resend. Set `RESEND_API_KEY` and
`FEEDBACK_FROM_EMAIL` as Worker secrets/variables; the recipient is fixed in
`worker.js`.

The endpoint is intentionally simple and unauthenticated because the app
cannot keep a secret. Before public deployment, configure a Cloudflare rate
limit for `POST /v1/feedback` (for example, a small per-IP hourly limit) and
ensure the Resend sender is a verified domain. Feedback may be retained by the
recipient's email system and Resend; the Worker does not write it to D1.

## Migrations

`migrations/` holds one file per schema change, applied by hand and in order
with `npx wrangler d1 execute est-telemetry --remote --config
telemetry/wrangler.local.toml --file=telemetry/migrations/<file>`.
`schema.sql` is the full current schema for a fresh database.

- `0001-product-column.sql`: adds `product` (default `est`) and reindexes
  on `(product, period, dedupe_key)`. Applied 2026-09-14.

## Deploy traps

- The tracked `wrangler.toml` holds a placeholder database id. Wrangler refuses
  to deploy with it: "binding DB of type d1 must have a valid `database_id`".
  Keep the real id in the gitignored `telemetry/wrangler.local.toml`.
- The feedback reply address is optional. The Worker validates it and drops a
  malformed one rather than rejecting the message, because the feedback still
  deserves to arrive. A valid address becomes the Resend `reply_to`.
