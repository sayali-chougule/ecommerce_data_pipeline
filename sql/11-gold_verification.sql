-- 1. Check table counts
SELECT
    'dim_customers' AS table_name,
    COUNT(*) AS row_count
FROM gold.dim_customers

UNION ALL

SELECT 'dim_products', COUNT(*)
FROM gold.dim_products

UNION ALL

SELECT 'dim_sellers', COUNT(*)
FROM gold.dim_sellers

UNION ALL

SELECT 'fact_order_items', COUNT(*)
FROM gold.fact_order_items;

-- 2. Verify fact grain
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (order_id, order_item_id)) AS unique_order_lines
FROM gold.fact_order_items;
-- Both numbers should match.

-- 3. Verify Silver-to-Gold reconciliation
SELECT
    (SELECT COUNT(*) FROM silver.order_items)
        AS silver_item_count,

    (SELECT COUNT(*) FROM gold.fact_order_items)
        AS gold_item_count;
-- The counts should match.

-- 4. Verify fact-to-dimension relationships
SELECT
    f.order_id,
    f.order_item_id,
    c.customer_state,
    p.product_category_english,
    s.seller_state,
    f.item_price
FROM gold.fact_order_items f

JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key

JOIN gold.dim_products p
    ON f.product_key = p.product_key

JOIN gold.dim_sellers s
    ON f.seller_key = s.seller_key

LIMIT 20;


-- Exploratory Queries

-- 1. Total merchandise value
SELECT
    ROUND(SUM(item_price), 2) AS total_item_value
FROM gold.fact_order_items;

-- 2. Delivered merchandise value by month
SELECT
    DATE_TRUNC('month', purchase_date)::DATE
        AS purchase_month,

    ROUND(SUM(item_price), 2)
        AS delivered_item_value

FROM gold.fact_order_items

WHERE order_status = 'delivered'
  AND purchase_date IS NOT NULL

GROUP BY 1
ORDER BY 1;

-- 3. Top 10 product categories
SELECT
    COALESCE(
        p.product_category_english,
        'unknown'
    ) AS category,

    COUNT(*) AS items_sold,

    ROUND(SUM(f.item_price), 2)
        AS item_value

FROM gold.fact_order_items f

JOIN gold.dim_products p
    ON f.product_key = p.product_key

WHERE f.order_status = 'delivered'

GROUP BY 1
ORDER BY item_value DESC
LIMIT 10;


-- 4. Sales by customer state
SELECT
    c.customer_state,

    COUNT(DISTINCT f.order_id)
        AS distinct_orders,

    COUNT(*)
        AS item_lines,

    ROUND(SUM(f.item_price), 2)
        AS item_value

FROM gold.fact_order_items f

JOIN gold.dim_customers c
    ON f.customer_key = c.customer_key

WHERE f.order_status = 'delivered'

GROUP BY c.customer_state
ORDER BY item_value DESC;