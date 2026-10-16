
-- ============================================================
-- Stage 8: Gold data quality assertions
--
-- Each SELECT returns:
-- check_name | dataset | failed_count
--
-- Expected failed_count = 0 for every check.
-- ============================================================

-- 1. Fact row-count reconciliation
SELECT
    'gold_fact_row_count' AS check_name,
    'gold.fact_order_items' AS dataset,
    ABS(
        (SELECT COUNT(*) FROM silver.order_items)
        -
        (SELECT COUNT(*) FROM gold.fact_order_items)
    )::BIGINT AS failed_count

UNION ALL

-- 2. Fact grain uniqueness
SELECT
    'gold_fact_grain_unique',
    'gold.fact_order_items',
    (
        SELECT COUNT(*) - COUNT(DISTINCT (order_id, order_item_id))
        FROM gold.fact_order_items
    )::BIGINT

UNION ALL

-- 3. Customer dimension reconciliation
SELECT
    'gold_customer_dimension',
    'gold.dim_customers',
    (
        SELECT COUNT(*)
        FROM silver.customers s
        WHERE NOT EXISTS (
            SELECT 1
            FROM gold.dim_customers g
            WHERE g.customer_id = s.customer_id
        )
    )::BIGINT

UNION ALL

-- 4. Product dimension reconciliation
SELECT
    'gold_product_dimension',
    'gold.dim_products',
    (
        SELECT COUNT(*)
        FROM silver.products s
        WHERE NOT EXISTS (
            SELECT 1
            FROM gold.dim_products g
            WHERE g.product_id = s.product_id
        )
    )::BIGINT

UNION ALL

-- 5. Seller dimension reconciliation
SELECT
    'gold_seller_dimension',
    'gold.dim_sellers',
    (
        SELECT COUNT(*)
        FROM silver.sellers s
        WHERE NOT EXISTS (
            SELECT 1
            FROM gold.dim_sellers g
            WHERE g.seller_id = s.seller_id
        )
    )::BIGINT

UNION ALL

-- 6. Monthly merchandise value reconciliation
SELECT
    'gold_monthly_value',
    'gold.vw_monthly_sales',
    CASE
        WHEN
            COALESCE(
                (SELECT SUM(merchandise_value)
                 FROM gold.vw_monthly_sales), 0
            )
            =
            COALESCE(
                (SELECT SUM(item_price)
                 FROM gold.fact_order_items
                 WHERE order_status = 'delivered'
                   AND purchase_date IS NOT NULL), 0
            )
        THEN 0
        ELSE 1
    END::BIGINT

UNION ALL

-- 7. Category merchandise value reconciliation
SELECT
    'gold_category_value',
    'gold.vw_category_performance',
    CASE
        WHEN
            COALESCE(
                (SELECT SUM(merchandise_value)
                 FROM gold.vw_category_performance), 0
            )
            =
            COALESCE(
                (SELECT SUM(item_price)
                 FROM gold.fact_order_items
                 WHERE order_status = 'delivered'), 0
            )
        THEN 0
        ELSE 1
    END::BIGINT;