SELECT * FROM bronze.customers;

SELECT COUNT(*) FROM bronze.customers;

SELECT DISTINCT customer_zip_code_prefix FROM bronze.customers;

SELECT DISTINCT customer_state FROM bronze.customers

SELECT * 
FROM bronze.customers
WHERE TRIM(customer_city) != customer_city;


SELECT * FROM bronze.orders;

SELECT * FROM bronze.orders
WHERE customer_id IS NULL;

SELECT DISTINCT order_status
FROM bronze.orders;

SELECT * FROM bronze.orders
WHERE order_purchase_timestamp IS NULL;

SELECT * FROM bronze.orders
WHERE order_approved_at IS NULL;

SELECT * FROM bronze.orders
WHERE order_purchase_timestamp > order_approved_at;

SELECT * FROM bronze.orders
WHERE order_purchase_timestamp > order_delivered_customer_date;

SELECT * FROM silver.orders;

SELECT DISTINCT order_status
FROM silver.orders;

SELECT * FROM bronze.products;

SELECT DISTINCT product_category_name
FROM bronze.products

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'bronze'
  AND table_name = 'products'
ORDER BY ordinal_position; 


SELECT * FROM bronze.sellers;

SELECT * FROM bronze.order_items;

SELECT * FROM bronze.payments;

SELECT DISTINCT payment_type
FROM bronze.payments;

SELECT * FROM silver.orders;

SELECT * FROM silver.payments;

SELECT
    review_score,
    COUNT(*) AS records
FROM bronze.reviews
GROUP BY review_score
ORDER BY review_score;

SELECT
    status,
    COUNT(*) AS total_runs
FROM etl.data_quality_runs
GROUP BY status;

SELECT
    q.run_id,
    q.status,
    COUNT(r.result_id) AS checks_executed
FROM etl.data_quality_runs q
LEFT JOIN etl.data_quality_results r
    ON q.run_id = r.run_id
GROUP BY q.run_id, q.status, q.started_at
ORDER BY q.started_at DESC
LIMIT 2;


SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'gold'
ORDER BY table_name;



-- Inspect pipeline history

SELECT
    pipeline_id,
    status,
    started_at,
    completed_at,
    error_message
FROM etl.pipeline_runs
ORDER BY started_at DESC
LIMIT 5;


-- Inspect step execution history

SELECT
    s.step_number,
    s.step_name,
    s.status,
    s.duration_seconds,
    s.exit_code
FROM etl.pipeline_step_runs s
WHERE s.pipeline_id = (
    SELECT pipeline_id
    FROM etl.pipeline_runs
    ORDER BY started_at DESC
    LIMIT 1
)
ORDER BY s.step_number;

-- Measure pipeline performance

SELECT
    step_name,
    COUNT(*) AS executions,
    ROUND(AVG(duration_seconds), 2)
        AS average_duration_seconds,
    ROUND(MAX(duration_seconds), 2)
        AS max_duration_seconds
FROM etl.pipeline_step_runs
WHERE status = 'SUCCESS'
GROUP BY step_name
ORDER BY average_duration_seconds DESC;



-- Verify the failure in PostgreSQL
SELECT
    p.pipeline_id,
    p.status AS pipeline_status,
    p.error_message AS pipeline_error,
    s.step_number,
    s.step_name,
    s.status AS step_status,
    s.exit_code,
    s.error_message AS step_error
FROM etl.pipeline_runs p
JOIN etl.pipeline_step_runs s
    ON p.pipeline_id = s.pipeline_id
WHERE p.status = 'FAILED'
ORDER BY p.started_at DESC
LIMIT 1;

-- These are the kinds of queries a data engineer might 
-- use when investigating a production pipeline.

-- A. Recent pipeline executions
SELECT
    pipeline_id,
    status,
    started_at,
    completed_at,
    ROUND(
        EXTRACT(
            EPOCH FROM completed_at - started_at
        )::NUMERIC,
        2
    ) AS total_duration_seconds
FROM etl.pipeline_runs
ORDER BY started_at DESC
LIMIT 10;

-- B. Failure rate
SELECT
    COUNT(*) AS completed_runs,

    COUNT(*) FILTER (
        WHERE status = 'FAILED'
    ) AS failed_runs,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE status = 'FAILED'
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS failure_rate_pct

FROM etl.pipeline_runs
WHERE status IN ('SUCCESS', 'FAILED');

-- C. Most frequently failing steps
SELECT
    step_name,

    COUNT(*) AS executions,

    COUNT(*) FILTER (
        WHERE status = 'FAILED'
    ) AS failures

FROM etl.pipeline_step_runs

GROUP BY step_name

ORDER BY failures DESC, executions DESC;

-- D. Find incomplete runs
SELECT
    pipeline_id,
    started_at,
    NOW() - started_at AS running_duration
FROM etl.pipeline_runs
WHERE status = 'RUNNING'
ORDER BY started_at;