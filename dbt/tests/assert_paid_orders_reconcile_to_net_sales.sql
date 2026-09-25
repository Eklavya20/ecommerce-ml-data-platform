select
    order_id,
    order_status,
    net_sales,
    successful_paid_amount
from {{ ref('int_orders_enriched') }}
where order_status in ('paid', 'completed')
  and abs(successful_paid_amount - net_sales) > 0.01

