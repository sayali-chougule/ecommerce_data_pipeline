CREATE SCHEMA IF NOT EXISTS etl;

CREATE TABLE IF NOT EXISTS etl.ingestion_batches (
    batch_id UUID PRIMARY KEY,
    source_file TEXT NOT NULL,
    target_table TEXT NOT NULL,
    status TEXT NOT NULL
        CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),
    rows_loaded BIGINT NOT NULL DEFAULT 0,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    error_message TEXT
);

-- Add metadata columns to each Bronze table.
-- These are safe to run more than once.

ALTER TABLE bronze.customers
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

ALTER TABLE bronze.orders
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

ALTER TABLE bronze.order_items
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

ALTER TABLE bronze.products
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

ALTER TABLE bronze.sellers
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

ALTER TABLE bronze.payments
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

ALTER TABLE bronze.reviews
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

ALTER TABLE bronze.geolocation
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;

ALTER TABLE bronze.product_category_translation
    ADD COLUMN IF NOT EXISTS batch_id UUID,
    ADD COLUMN IF NOT EXISTS source_file TEXT,
    ADD COLUMN IF NOT EXISTS ingested_at TIMESTAMPTZ;