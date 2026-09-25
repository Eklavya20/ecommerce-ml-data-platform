select
    order_id::bigint as order_id,
    customer_id::bigint as customer_id,
    lower(trim(order_status))::text as order_status,
    lower(trim(sales_channel))::text as sales_channel,
    upper(trim(currency))::text as currency,
    ordered_at::timestamptz as ordered_at,
    updated_at::timestamptz as updated_at,
    _loaded_at::timestamptz as source_loaded_at
from {{ source('ecommerce', 'orders') }}

