
-- ============================================================
-- Stage 7: Gold analytical views
-- ============================================================

-- VIEW 1: One row per order represented in the item fact.
-- Grain: order_id

CREATE OR REPLACE VIEW gold.vw_order_metrics AS
SELECT
    f.order_id,
    f.customer_key,
    f.order_status,
    f.order_purchase_timestamp,
    f.purchase_date,

    COUNT(*) AS item_count,

    SUM(f.item_price)::NUMERIC(18,2)
        AS merchandise_value,

    SUM(COALESCE(f.freight_value, 0))::NUMERIC(18,2)
        AS freight_value,

    SUM(
        f.item_price + COALESCE(f.freight_value, 0)
    )::NUMERIC(18,2)
        AS merchandise_plus_freight

FROM gold.fact_order_items f

GROUP BY
    f.order_id,
    f.customer_key,
    f.order_status,
    f.order_purchase_timestamp,
    f.purchase_date;



-- VIEW 2: Monthly delivered sales performance
-- Grain: purchase_month
-- Business rule: only delivered orders

CREATE OR REPLACE VIEW gold.vw_monthly_sales AS
SELECT
    DATE_TRUNC(
        'month',
        purchase_date
    )::DATE AS purchase_month,

    COUNT(*) AS delivered_orders,

    SUM(item_count) AS items_sold,

    SUM(merchandise_value)::NUMERIC(18,2)
        AS merchandise_value,

    SUM(freight_value)::NUMERIC(18,2)
        AS freight_value,

    ROUND(
        SUM(merchandise_value)
        / NULLIF(COUNT(*), 0),
        2
    ) AS average_order_value,

    ROUND(
        SUM(merchandise_value)
        / NULLIF(SUM(item_count), 0),
        2
    ) AS average_item_price

FROM gold.vw_order_metrics

WHERE order_status = 'delivered'
  AND purchase_date IS NOT NULL

GROUP BY
    DATE_TRUNC('month', purchase_date)::DATE;



-- VIEW 3: Delivered item performance by category
-- Grain: product category

CREATE OR REPLACE VIEW gold.vw_category_performance AS
SELECT
    COALESCE(
        p.product_category_english,
        'unknown'
    ) AS category_name,

    COUNT(*) AS items_sold,

    COUNT(DISTINCT f.order_id)
        AS distinct_orders,

    SUM(f.item_price)::NUMERIC(18,2)
        AS merchandise_value,

    SUM(COALESCE(f.freight_value, 0))::NUMERIC(18,2)
        AS freight_value,

    ROUND(AVG(f.item_price), 2)
        AS average_item_price

FROM gold.fact_order_items f

JOIN gold.dim_products p
    ON f.product_key = p.product_key

WHERE f.order_status = 'delivered'

GROUP BY
    COALESCE(
        p.product_category_english,
        'unknown'
    );



-- VIEW 4: Delivered sales by customer state
-- Grain: customer_state

CREATE OR REPLACE VIEW gold.vw_state_performance AS
SELECT
    COALESCE(
        c.customer_state,
        'UNKNOWN'
    ) AS customer_state,

    COUNT(*) AS delivered_orders,

    SUM(o.item_count) AS items_sold,

    SUM(o.merchandise_value)::NUMERIC(18,2)
        AS merchandise_value,

    ROUND(
        SUM(o.merchandise_value)
        / NULLIF(COUNT(*), 0),
        2
    ) AS average_order_value

FROM gold.vw_order_metrics o

JOIN gold.dim_customers c
    ON o.customer_key = c.customer_key

WHERE o.order_status = 'delivered'

GROUP BY
    COALESCE(
        c.customer_state,
        'UNKNOWN'
    );



-- VIEW 5: Delivered purchase history by unique customer
-- Grain: customer_unique_id

CREATE OR REPLACE VIEW gold.vw_customer_purchase_summary AS
SELECT
    c.customer_unique_id,

    COUNT(*) AS delivered_orders,

    SUM(o.item_count) AS items_purchased,

    SUM(o.merchandise_value)::NUMERIC(18,2)
        AS lifetime_delivered_merchandise_value,

    MIN(o.purchase_date) AS first_purchase_date,

    MAX(o.purchase_date) AS last_purchase_date,

    CASE
        WHEN COUNT(*) >= 2 THEN TRUE
        ELSE FALSE
    END AS is_repeat_customer

FROM gold.vw_order_metrics o

JOIN gold.dim_customers c
    ON o.customer_key = c.customer_key

WHERE o.order_status = 'delivered'

GROUP BY
    c.customer_unique_id;