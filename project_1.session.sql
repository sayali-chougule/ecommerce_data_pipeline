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