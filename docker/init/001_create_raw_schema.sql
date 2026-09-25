CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE IF NOT EXISTS raw.customers (
    customer_id BIGINT PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    country_code VARCHAR(2) NOT NULL
        CHECK (country_code IN ('DE', 'AT', 'CH', 'NL', 'FR')),
    acquisition_channel TEXT NOT NULL
        CHECK (acquisition_channel IN ('organic', 'paid_search', 'referral', 'affiliate')),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.products (
    product_id BIGINT PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    product_name TEXT NOT NULL,
    category TEXT NOT NULL
        CHECK (category IN ('electronics', 'home', 'sports', 'books', 'beauty')),
    list_price NUMERIC(12, 2) NOT NULL CHECK (list_price >= 0),
    unit_cost NUMERIC(12, 2) NOT NULL CHECK (unit_cost >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (unit_cost <= list_price)
);

CREATE TABLE IF NOT EXISTS raw.orders (
    order_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL REFERENCES raw.customers(customer_id),
    order_status TEXT NOT NULL
        CHECK (order_status IN ('pending', 'paid', 'completed', 'cancelled')),
    sales_channel TEXT NOT NULL
        CHECK (sales_channel IN ('web', 'mobile', 'marketplace')),
    currency CHAR(3) NOT NULL CHECK (currency = 'EUR'),
    ordered_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.order_items (
    order_item_id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES raw.orders(order_id),
    product_id BIGINT NOT NULL REFERENCES raw.products(product_id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
    discount_amount NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (discount_amount <= quantity * unit_price)
);

CREATE TABLE IF NOT EXISTS raw.payments (
    payment_id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES raw.orders(order_id),
    payment_method TEXT NOT NULL
        CHECK (payment_method IN ('card', 'paypal', 'bank_transfer')),
    payment_status TEXT NOT NULL
        CHECK (payment_status IN ('pending', 'succeeded', 'failed')),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
    attempted_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS raw.returns (
    return_id BIGINT PRIMARY KEY,
    order_item_id BIGINT NOT NULL REFERENCES raw.order_items(order_item_id),
    return_quantity INTEGER NOT NULL CHECK (return_quantity > 0),
    refund_amount NUMERIC(12, 2) NOT NULL CHECK (refund_amount >= 0),
    return_reason TEXT NOT NULL
        CHECK (return_reason IN ('damaged', 'unwanted', 'wrong_item', 'defective', 'late_delivery')),
    returned_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON raw.orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON raw.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON raw.order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON raw.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_returns_order_item_id ON raw.returns(order_item_id);

