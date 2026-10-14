SELECT 'customers' AS table_name, COUNT(*) AS rows
FROM bronze.customers

UNION ALL
SELECT 'orders', COUNT(*)
FROM bronze.orders

UNION ALL
SELECT 'order_items', COUNT(*)
FROM bronze.order_items

UNION ALL
SELECT 'products', COUNT(*)
FROM bronze.products

UNION ALL
SELECT 'sellers', COUNT(*)
FROM bronze.sellers

UNION ALL
SELECT 'payments', COUNT(*)
FROM bronze.payments

UNION ALL
SELECT 'reviews', COUNT(*)
FROM bronze.reviews

UNION ALL
SELECT 'geolocation', COUNT(*)
FROM bronze.geolocation

UNION ALL
SELECT 'product_category_translation', COUNT(*)
FROM bronze.product_category_translation

ORDER BY table_name;


SELECT
    source_file,
    target_table,
    status,
    rows_loaded,
    started_at,
    completed_at
FROM etl.ingestion_batches
ORDER BY started_at DESC;

SELECT
    order_id,
    order_status,
    batch_id,
    source_file,
    ingested_at
FROM bronze.orders
LIMIT 5;


SELECT COUNT(*) AS missing_metadata
FROM bronze.orders
WHERE batch_id IS NULL
   OR source_file IS NULL
   OR ingested_at IS NULL;