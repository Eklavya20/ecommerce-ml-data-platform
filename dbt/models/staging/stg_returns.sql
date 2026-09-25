select
    return_id::bigint as return_id,
    order_item_id::bigint as order_item_id,
    return_quantity::integer as return_quantity,
    refund_amount::numeric(12, 2) as refund_amount,
    lower(trim(return_reason))::text as return_reason,
    returned_at::timestamptz as returned_at,
    updated_at::timestamptz as updated_at,
    _loaded_at::timestamptz as source_loaded_at
from {{ source('ecommerce', 'returns') }}

