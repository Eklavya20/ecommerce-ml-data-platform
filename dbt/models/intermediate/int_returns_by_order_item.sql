select
    order_item_id,
    sum(return_quantity)::integer as returned_quantity,
    sum(refund_amount)::numeric(14, 2) as refund_amount,
    count(*)::integer as return_event_count,
    max(greatest(updated_at, source_loaded_at)) as return_updated_at
from {{ ref('stg_returns') }}
group by order_item_id

