select
    order_item_id::bigint as order_item_id,
    order_id::bigint as order_id,
    product_id::bigint as product_id,
    quantity::integer as quantity,
    unit_price::numeric(12, 2) as unit_price,
    discount_amount::numeric(12, 2) as discount_amount,
    created_at::timestamptz as created_at,
    updated_at::timestamptz as updated_at,
    _loaded_at::timestamptz as source_loaded_at
from {{ source('ecommerce', 'order_items') }}

