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

-- Orders
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
CREATE TABLE IF NOT EXISTS silver.sellers(
    seller_id TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city TEXT,
    seller_state TEXT,
    source_batch_id UUID,
    transformed_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Order Items
CREATE TABLE IF NOT EXISTS silver.order_items( 
    order_id TEXT,
    order_item_id INT,
    product_id TEXT,
    seller_id TEXT,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    source_batch_id UUID,
    transformed_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT order_id_fk
        FOREIGN KEY (order_id)
        REFERENCES silver.orders(order_id),

    CONSTRAINT product_id_fk
        FOREIGN KEY (product_id)
        REFERENCES silver.products(product_id),

    CONSTRAINT seller_id_fk
        FOREIGN KEY (seller_id)
        REFERENCES silver.sellers(seller_id),

    CONSTRAINT chk_item_price
        CHECK (price >= 0),

    CONSTRAINT chk_freight_value
        CHECK (freight_value >= 0)
);

-- 6. Payments

CREATE TABLE IF NOT EXISTS silver.payments(
    order_id TEXT,
    payment_sequential INT,
    payment_type TEXT,
    payment_installments INT,
    payment_value NUMERIC(12,2),
    source_batch_id UUID,
    transformed_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT payment_order_fk      
        FOREIGN KEY (order_id)
        REFERENCES silver.orders(order_id),

    CONSTRAINT chk_payment_installments
        CHECK (payment_installments >= 0),

    CONSTRAINT chk_payment_value
        CHECK (payment_value >= 0) 
);