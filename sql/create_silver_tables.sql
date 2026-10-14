CREATE SCHEMA IF NOT EXISTS silver;

-- Clean customer records
CREATE TABLE IF NOT EXISTS silver.customers (
    customer_id TEXT PRIMARY KEY,
    customer_unique_id TEXT NOT NULL,
    customer_zip_code_prefix TEXT,
    customer_city TEXT,
    customer_state TEXT,
    source_batch_id UUID,
    transformed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Clean order records
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
        REFERENCES silver.customers(customer_id),

    CONSTRAINT chk_order_status
        CHECK (
            order_status IN (
                'created',
                'approved',
                'invoiced',
                'processing',
                'shipped',
                'delivered',
                'unavailable',
                'canceled'
            )
        )
);
