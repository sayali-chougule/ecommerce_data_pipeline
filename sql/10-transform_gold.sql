
-- Stage 6: Silver -> Gold transformation
-- Full refresh, executed as one transaction

BEGIN;

-- Refresh all four related tables together.
TRUNCATE TABLE
    gold.fact_order_items,
    gold.dim_customers,
    gold.dim_products,
    gold.dim_sellers
RESTART IDENTITY;

-- ==========================================
-- 1. Customer dimension
-- ==========================================

INSERT INTO gold.dim_customers (
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix
)
SELECT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix
FROM silver.customers;

-- ==========================================
-- 2. Product dimension
-- ==========================================

INSERT INTO gold.dim_products (
    product_id,
    product_category_name,
    product_category_english,
    product_weight_g
)
SELECT
    p.product_id,
    p.product_category_name,
    t.product_category_name_english,
    p.product_weight_g
FROM silver.products p
LEFT JOIN silver.product_category_translation t
    ON p.product_category_name = t.product_category_name;

-- ==========================================
-- 3. Seller dimension
-- ==========================================

INSERT INTO gold.dim_sellers (
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
)
SELECT
    seller_id,
    seller_city,
    seller_state,
    seller_zip_code_prefix
FROM silver.sellers;

-- ==========================================
-- 4. Order-item fact
-- ==========================================

INSERT INTO gold.fact_order_items (
    order_id,
    order_item_id,
    customer_key,
    product_key,
    seller_key,
    order_purchase_timestamp,
    purchase_date,
    order_status,
    item_price,
    freight_value
)
SELECT
    oi.order_id,
    oi.order_item_id,

    dc.customer_key,
    dp.product_key,
    ds.seller_key,

    o.order_purchase_timestamp,
    o.order_purchase_timestamp::DATE,
    o.order_status,

    oi.price,
    oi.freight_value

FROM silver.order_items oi

JOIN silver.orders o
    ON oi.order_id = o.order_id

JOIN gold.dim_customers dc
    ON o.customer_id = dc.customer_id

JOIN gold.dim_products dp
    ON oi.product_id = dp.product_id

JOIN gold.dim_sellers ds
    ON oi.seller_id = ds.seller_id;

-- Verify that the fact transformation
-- did not lose any order-item records.
DO $$
DECLARE
    silver_count BIGINT;
    gold_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO silver_count
    FROM silver.order_items;

    SELECT COUNT(*) INTO gold_count
    FROM gold.fact_order_items;

    IF silver_count <> gold_count THEN
        RAISE EXCEPTION
            'Gold fact row count mismatch: Silver %, Gold %',
            silver_count, gold_count;
    END IF;
END
$$;

COMMIT;