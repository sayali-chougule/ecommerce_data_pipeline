SELECT 'products' AS dataset,
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
       (SELECT COUNT(*) FROM silver.payments);

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