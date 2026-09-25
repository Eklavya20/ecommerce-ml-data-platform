select
    order_items.order_item_id,
    order_items.quantity as purchased_quantity,
    returns.returned_quantity
from {{ ref('stg_order_items') }} as order_items
inner join {{ ref('int_returns_by_order_item') }} as returns using (order_item_id)
where returns.returned_quantity > order_items.quantity

