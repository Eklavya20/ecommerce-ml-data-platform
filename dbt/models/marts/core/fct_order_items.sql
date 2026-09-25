select
    order_item_id,
    order_id,
    product_id,
    quantity,
    returned_quantity,
    return_event_count,
    unit_price,
    unit_cost,
    gross_amount,
    discount_amount,
    net_sales,
    refund_amount,
    post_refund_revenue,
    cost,
    margin,
    source_updated_at
from {{ ref('int_order_item_financials') }}

