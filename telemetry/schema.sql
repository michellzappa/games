CREATE TABLE IF NOT EXISTS telemetry_batches (
  batch_id TEXT PRIMARY KEY,
  received_at TEXT NOT NULL,
  product TEXT NOT NULL DEFAULT 'est',
  period TEXT NOT NULL,
  dedupe_key TEXT NOT NULL,
  cohort TEXT,
  app_version TEXT NOT NULL,
  app_build TEXT NOT NULL,
  ios_major INTEGER NOT NULL,
  device_family TEXT NOT NULL,
  payload TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS telemetry_batches_product_period_dedupe
  ON telemetry_batches (product, period, dedupe_key);

CREATE INDEX IF NOT EXISTS telemetry_batches_product_period
  ON telemetry_batches (product, period);
