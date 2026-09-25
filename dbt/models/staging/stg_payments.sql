select
    payment_id::bigint as payment_id,
    order_id::bigint as order_id,
    lower(trim(payment_method))::text as payment_method,
    lower(trim(payment_status))::text as payment_status,
    amount::numeric(12, 2) as amount,
    attempted_at::timestamptz as attempted_at,
    updated_at::timestamptz as updated_at,
    _loaded_at::timestamptz as source_loaded_at
from {{ source('ecommerce', 'payments') }}

