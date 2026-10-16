
-- Stage 5: Gold dimensional model

CREATE SCHEMA IF NOT EXISTS gold;

-- 1. Customer dimension
CREATE TABLE IF NOT EXISTS gold.dim_customers (
    customer_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id TEXT NOT NULL UNIQUE,
    customer_unique_id TEXT NOT NULL,
    customer_city TEXT,
    customer_state TEXT,
    customer_zip_code_prefix TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Product dimension
CREATE TABLE IF NOT EXISTS gold.dim_products (
    product_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id TEXT NOT NULL UNIQUE,
    product_category_name TEXT,
    product_category_english TEXT,
    product_weight_g NUMERIC(12,2),
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Seller dimension
CREATE TABLE IF NOT EXISTS gold.dim_sellers (
    seller_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id TEXT NOT NULL UNIQUE,
    seller_city TEXT,
    seller_state TEXT,
    seller_zip_code_prefix TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. Order-item fact table
CREATE TABLE IF NOT EXISTS gold.fact_order_items (
    order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,

    customer_key BIGINT NOT NULL
        REFERENCES gold.dim_customers(customer_key),

    product_key BIGINT NOT NULL
        REFERENCES gold.dim_products(product_key),

    seller_key BIGINT NOT NULL
        REFERENCES gold.dim_sellers(seller_key),

    order_purchase_timestamp TIMESTAMP,
    purchase_date DATE,
    order_status TEXT NOT NULL,

    item_price NUMERIC(12,2) NOT NULL,
    freight_value NUMERIC(12,2),

    loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT chk_fact_item_price
        CHECK (item_price >= 0),

    CONSTRAINT chk_fact_freight
        CHECK (freight_value >= 0)
);

-- Indexes on fact foreign keys
CREATE INDEX IF NOT EXISTS idx_fact_customer
    ON gold.fact_order_items(customer_key);

CREATE INDEX IF NOT EXISTS idx_fact_product
    ON gold.fact_order_items(product_key);

CREATE INDEX IF NOT EXISTS idx_fact_seller
    ON gold.fact_order_items(seller_key);

CREATE INDEX IF NOT EXISTS idx_fact_purchase_date
    ON gold.fact_order_items(purchase_date);
