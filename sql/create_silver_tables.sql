CREATE SCHEMA IF NOT EXISTS silver;

-- 1. Customer
CREATE TABLE IF NOT EXISTS silver.customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT NOT NULL,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT,
    source_batch_id UUID,
    transformed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Records
CREATE TABLE IF NOT EXISTS silver.orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    order_status TEXT NOT NULL,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    source_batch_id UUID,
    transformed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES silver.customers(customer_id)
);

-- 3. Products
CREATE TABLE IF NOT EXISTS silver.products(
    product_id TEXT PRIMARY KEY,
    product_category_name TEXT,
    product_name_length INT,
    product_description_length INT,
    product_photos_quantity INT,
    product_weight_g NUMERIC(12,2),
    product_length_cm NUMERIC(12,2),
    product_height_cm NUMERIC(12,2),
    product_width_cm NUMERIC(12,2),
    source_batch_id UUID,
    transformed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_product_weight
        CHECK (product_weight_g >= 0),

    CONSTRAINT chk_product_dimensions
        CHECK (
            product_length_cm >= 0
            AND product_height_cm >= 0
            AND product_width_cm >= 0
        )
);

-- 4. Sellers