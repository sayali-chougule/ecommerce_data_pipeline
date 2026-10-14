SELECT 'customers' AS dataset,
       (SELECT COUNT(*) FROM bronze.customers) AS bronze_count,
       (SELECT COUNT(*) FROM silver.customers) AS silver_count

UNION ALL
SELECT 'orders',
       (SELECT COUNT(*) FROM bronze.orders) AS bronze_count,
       (SELECT COUNT(*) FROM silver.orders) AS silver_count

UNION ALL
SELECT 'products',
       (SELECT COUNT(*) FROM bronze.products) AS bronze_count,
       (SELECT COUNT(*) FROM silver.products) AS silver_count

UNION ALL
SELECT 'sellers',
       (SELECT COUNT(*) FROM bronze.sellers),
       (SELECT COUNT(*) FROM silver.sellers)

UNION ALL
SELECT 'order_items',
       (SELECT COUNT(*) FROM bronze.order_items),
       (SELECT COUNT(*) FROM silver.order_items)

UNION ALL
SELECT 'payments',
       (SELECT COUNT(*) FROM bronze.payments),
       (SELECT COUNT(*) FROM silver.payments)

UNION ALL
SELECT
    'reviews',
    (SELECT COUNT(*) FROM bronze.reviews) AS bronze_rows,
    (SELECT COUNT(*) FROM silver.reviews) AS silver_rows;

UNION ALL
SELECT
    'geolocation',
    (SELECT COUNT(*) FROM bronze.geolocation),
    (SELECT COUNT(*) FROM silver.geolocation)

UNION ALL
SELECT
    'product_category_translation',
    (SELECT COUNT(*) FROM bronze.product_category_translation),
    (SELECT COUNT(*) FROM silver.product_category_translation);

-- Verify monetary values
SELECT
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    ROUND(AVG(price), 2) AS avg_price
FROM silver.order_items;

-- Check referential integrity
SELECT COUNT(*) AS orphan_items
FROM silver.order_items oi
LEFT JOIN silver.orders o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Check payment types
SELECT
    payment_type,
    COUNT(*) AS payment_records,
    SUM(payment_value) AS total_payment_value
FROM silver.payments
GROUP BY payment_type
ORDER BY payment_records DESC;

-- Nine Silver tables.
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'silver'
ORDER BY table_name;

-- Verify review score distribution
SELECT
    review_score,
    COUNT(*) AS review_count
FROM silver.reviews
GROUP BY review_score
ORDER BY review_score;

-- Investigate repeated ZIP-code prefixes
SELECT
    geolocation_zip_code_prefix,
    COUNT(*) AS observations
FROM silver.geolocation
GROUP BY geolocation_zip_code_prefix
ORDER BY observations DESC
LIMIT 10;

-- Check product category translations
SELECT
    p.product_category_name,
    t.product_category_name_english
FROM silver.products p
LEFT JOIN silver.product_category_translation t
    ON p.product_category_name = t.product_category_name
LIMIT 20;

-- Verify all nine Silver tables
SELECT COUNT(*) AS silver_table_count
FROM information_schema.tables
WHERE table_schema = 'silver'
  AND table_type = 'BASE TABLE';