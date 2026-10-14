
-- =====================================================
-- Stage 2: Bronze -> Silver full refresh
-- Customers, Orders, Products, Sellers,
-- Order Items, Payments
-- =====================================================

BEGIN;

-- All related tables are refreshed together.
TRUNCATE TABLE
    silver.reviews,
    silver.geolocation,
    silver.product_category_translation,
    silver.payments,
    silver.order_items,
    silver.sellers,
    silver.products,
    silver.orders,
    silver.customers
RESTART IDENTITY;   -- new review and geolocation tables have auto-generated surrogate keys.
                    -- resets their identity sequences during a full refresh.

-- 1. Customers
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

-- 2. Orders
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

-- 3. Products
INSERT INTO silver.products (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_quantity,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    source_batch_id
)
SELECT
    NULLIF(TRIM(product_id), ''),
    LOWER(NULLIF(TRIM(product_category_name), '')),
    NULLIF(TRIM(product_name_lenght), '')::INTEGER,
    NULLIF(TRIM(product_description_lenght), '')::INTEGER,
    NULLIF(TRIM(product_photos_qty), '')::INTEGER,
    NULLIF(TRIM(product_weight_g), '')::NUMERIC(12,2),
    NULLIF(TRIM(product_length_cm), '')::NUMERIC(12,2),
    NULLIF(TRIM(product_height_cm), '')::NUMERIC(12,2),
    NULLIF(TRIM(product_width_cm), '')::NUMERIC(12,2),
    batch_id
FROM bronze.products;

-- 4. Sellers
INSERT INTO silver.sellers (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    source_batch_id
)
SELECT
    NULLIF(TRIM(seller_id), ''),
    NULLIF(TRIM(seller_zip_code_prefix), ''),
    LOWER(NULLIF(TRIM(seller_city), '')),
    UPPER(NULLIF(TRIM(seller_state), '')),
    batch_id
FROM bronze.sellers;

-- 5. Order Items
INSERT INTO silver.order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    source_batch_id
)
SELECT
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(order_item_id), '')::INTEGER,
    NULLIF(TRIM(product_id), ''),
    NULLIF(TRIM(seller_id), ''),
    NULLIF(TRIM(shipping_limit_date), '')::TIMESTAMP,
    NULLIF(TRIM(price), '')::NUMERIC(12,2),
    NULLIF(TRIM(freight_value), '')::NUMERIC(12,2),
    batch_id
FROM bronze.order_items;

-- 6. Payments
INSERT INTO silver.payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value,
    source_batch_id
)
SELECT
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(payment_sequential), '')::INTEGER,
    LOWER(NULLIF(TRIM(payment_type), '')),
    NULLIF(TRIM(payment_installments), '')::INTEGER,
    NULLIF(TRIM(payment_value), '')::NUMERIC(12,2),
    batch_id
FROM bronze.payments;

-- 7. Order Reviews
INSERT INTO silver.reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp,
    source_batch_id
)
SELECT
    NULLIF(TRIM(review_id), ''),
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(review_score), '')::INTEGER,
    NULLIF(TRIM(review_comment_title), ''),
    NULLIF(TRIM(review_comment_message), ''),
    NULLIF(TRIM(review_creation_date), '')::TIMESTAMP,
    NULLIF(TRIM(review_answer_timestamp), '')::TIMESTAMP,
    batch_id
FROM bronze.reviews;


-- 8. Geolocation
INSERT INTO silver.geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state,
    source_batch_id
)
SELECT
    NULLIF(TRIM(geolocation_zip_code_prefix), ''),
    NULLIF(TRIM(geolocation_lat), '')::DOUBLE PRECISION,
    NULLIF(TRIM(geolocation_lng), '')::DOUBLE PRECISION,
    LOWER(NULLIF(TRIM(geolocation_city), '')),
    UPPER(NULLIF(TRIM(geolocation_state), '')),
    batch_id
FROM bronze.geolocation;


-- 9. Product Category Translation
INSERT INTO silver.product_category_translation (
    product_category_name,
    product_category_name_english,
    source_batch_id
)
SELECT
    LOWER(NULLIF(TRIM(product_category_name), '')),
    LOWER(NULLIF(TRIM(product_category_name_english), '')),
    batch_id
FROM bronze.product_category_translation;

COMMIT;