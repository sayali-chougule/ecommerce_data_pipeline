-- Transform Bronze to Silver

BEGIN;

TRUNCATE TABLE silver.orders, silver.customers;

-- 1. Clean and load customers

INSERT INTO silver.customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    source_batch_id
)
SELECT
    NULLIF(TRIM(customer_id), ''),
    NULLIF(TRIM(customer_unique_id), ''),
    NULLIF(TRIM(customer_zip_code_prefix), ''),
    LOWER(NULLIF(TRIM(customer_city), '')),
    UPPER(NULLIF(TRIM(customer_state), '')),
    batch_id
FROM bronze.customers;

-- 2. Clean and load orders

INSERT INTO silver.orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    source_batch_id
)
SELECT
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(customer_id), ''),
    LOWER(TRIM(order_status)),

    NULLIF(TRIM(order_purchase_timestamp), '')::TIMESTAMP,
    NULLIF(TRIM(order_approved_at), '')::TIMESTAMP,
    NULLIF(TRIM(order_delivered_carrier_date), '')::TIMESTAMP,
    NULLIF(TRIM(order_delivered_customer_date), '')::TIMESTAMP,
    NULLIF(TRIM(order_estimated_delivery_date), '')::TIMESTAMP,

    batch_id
FROM bronze.orders;

COMMIT;