-- Adds the product column for the multi-game Worker. Every existing row is
-- EST. The unique index gains the product so two games on one device keep
-- separate weekly rows.
ALTER TABLE telemetry_batches ADD COLUMN product TEXT NOT NULL DEFAULT 'est';
DROP INDEX IF EXISTS telemetry_batches_period_dedupe;
CREATE UNIQUE INDEX IF NOT EXISTS telemetry_batches_product_period_dedupe
  ON telemetry_batches (product, period, dedupe_key);
DROP INDEX IF EXISTS telemetry_batches_period;
CREATE INDEX IF NOT EXISTS telemetry_batches_product_period
  ON telemetry_batches (product, period);
