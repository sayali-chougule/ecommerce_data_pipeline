-- ===================================================
-- OLIST E-COMMERCE: BRONZE LAYER
-- Database: ecommerce_dw
-- ===================================================

-- 1. Customers

DROP TABLE IF EXISTS bronze.customers;

CREATE TABLE bronze.customers(
    customer_id                 TEXT,
    customer_unique_id          TEXT,
    customer_zip_code_prefix    TEXT,
    customer_city               TEXT,
    customer_state              TEXT
);

-- 2. Orders

DROP TABLE IF EXISTS bronze.orders;

CREATE TABLE bronze.orders(
    order_id                         TEXT,
    customer_id                      TEXT,
    order_status                     TEXT,
    order_purchase_timestamp         TEXT,
    order_approved_at                TEXT,
    order_delivered_carrier_date     TEXT,
    order_delivered_customer_date    TEXT,
    order_estimated_delivery_date    TEXT
);

-- 3. Order Items

DROP TABLE IF EXISTS bronze.order_items;

CREATE TABLE bronze.order_items(
order_id                TEXT,
order_item_id           TEXT,
product_id              TEXT,
seller_id               TEXT,
shipping_limit_date     TEXT,
price                   TEXT,
freight_value          TEXT
);

-- 4. Products

DROP TABLE IF EXISTS bronze.products;

CREATE TABLE bronze.products(
    product_id                     TEXT,
    product_category_name          TEXT,
    product_name_lenght            TEXT,
    product_description_lenght     TEXT,
    product_photos_qty             TEXT,
    product_weight_g               TEXT,
    product_length_cm              TEXT,
    product_height_cm              TEXT,
    product_width_cm               TEXT
);

-- 5. Sellers

DROP TABLE IF EXISTS bronze.sellers;

CREATE TABLE bronze.sellers(
    seller_id                 TEXT,
    seller_zip_code_prefix    TEXT,
    seller_city               TEXT,
    seller_state              TEXT
);

-- 6. Payments

DROP TABLE IF EXISTS bronze.payments;

CREATE TABLE bronze.payments( 
    order_id                 TEXT,
    payment_sequential       TEXT,
    payment_type             TEXT,
    payment_installments     TEXT,
    payment_value            TEXT
);

-- 7. Reviews

DROP TABLE IF EXISTS bronze.reviews;

CREATE TABLE bronze.reviews(
    review_id                  TEXT,
    order_id                   TEXT,
    review_score               TEXT,
    review_comment_title       TEXT,
    review_comment_message     TEXT,
    review_creation_date       TEXT,
    review_answer_timestamp    TEXT
);

-- 8. Geolocation

DROP TABLE IF EXISTS bronze.geolocation;

CREATE TABLE bronze.geolocation(
    geolocation_zip_code_prefix      TEXT,
    geolocation_lat                  TEXT,
    geolocation_lng                  TEXT,
    geolocation_city                 TEXT,
    geolocation_state                TEXT
);

-- 9. Product Category Translation

DROP TABLE IF EXISTS bronze.product_category_translation;


CREATE TABLE bronze.product_category_translation(
    product_category_name            TEXT,
    product_category_name_english    TEXT
);