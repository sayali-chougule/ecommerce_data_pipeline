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
WHERE order_purchase_timestamp < order_approved_at;