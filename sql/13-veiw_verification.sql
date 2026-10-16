-- Verify that PostgreSQL created the views:
SELECT
    table_name AS view_name
FROM information_schema.views
WHERE table_schema = 'gold'
ORDER BY table_name;


-- 1. Order-level grain
SELECT
    COUNT(*) AS view_rows,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM gold.vw_order_metrics;
-- The two numbers must match.

-- verify that no order-item records were lost:
SELECT
    (SELECT COUNT(*)
     FROM gold.fact_order_items) AS fact_item_lines,

    (SELECT SUM(item_count)
     FROM gold.vw_order_metrics) AS aggregated_item_lines;
-- Expected: both totals match.

-- 2. Monthly reconciliation
SELECT
    (
        SELECT SUM(merchandise_value)
        FROM gold.vw_monthly_sales
    ) AS monthly_total,

    (
        SELECT SUM(item_price)
        FROM gold.fact_order_items
        WHERE order_status = 'delivered'
          AND purchase_date IS NOT NULL
    ) AS fact_total;
-- Expected: both totals match.

-- 3. Category reconciliation
SELECT
    (
        SELECT SUM(merchandise_value)
        FROM gold.vw_category_performance
    ) AS category_total,

    (
        SELECT SUM(item_price)
        FROM gold.fact_order_items
        WHERE order_status = 'delivered'
    ) AS fact_total;
-- Expected: both totals match.

-- 4. Customer-state reconciliation
SELECT
    (
        SELECT SUM(delivered_orders)
        FROM gold.vw_state_performance
    ) AS state_order_total,

    (
        SELECT COUNT(*)
        FROM gold.vw_order_metrics
        WHERE order_status = 'delivered'
    ) AS overall_delivered_orders;
-- Expected: both counts match.

-- 5. Repeat-customer classification
SELECT
    COUNT(*) AS customers_with_delivered_orders,

    COUNT(*) FILTER (
        WHERE is_repeat_customer
    ) AS repeat_customers,

    COUNT(*) FILTER (
        WHERE NOT is_repeat_customer
    ) AS one_time_customers,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE is_repeat_customer
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_percentage

FROM gold.vw_customer_purchase_summary;
-- This calculates the percentage of observed 
-- customers with at least two delivered orders.

-- 6. Explore the business results
-- a. Monthly merchandise value and AOV
SELECT
    purchase_month,
    delivered_orders,
    items_sold,
    merchandise_value,
    average_order_value
FROM gold.vw_monthly_sales
ORDER BY purchase_month;

-- b. Top 10 product categories
SELECT
    category_name,
    items_sold,
    distinct_orders,
    merchandise_value
FROM gold.vw_category_performance
ORDER BY merchandise_value DESC
LIMIT 10;

-- c. Top customer states
SELECT
    customer_state,
    delivered_orders,
    merchandise_value,
    average_order_value
FROM gold.vw_state_performance
ORDER BY merchandise_value DESC
LIMIT 10;

-- d. Monthly growth rate
WITH monthly AS (
    SELECT
        purchase_month,
        merchandise_value,
        LAG(merchandise_value) OVER (
            ORDER BY purchase_month
        ) AS previous_month_value
    FROM gold.vw_monthly_sales
)
SELECT
    purchase_month,
    merchandise_value,
    previous_month_value,

    ROUND(
        100.0 *
        (merchandise_value - previous_month_value)
        / NULLIF(previous_month_value, 0),
        2
    ) AS month_over_month_growth_pct

FROM monthly
ORDER BY purchase_month;