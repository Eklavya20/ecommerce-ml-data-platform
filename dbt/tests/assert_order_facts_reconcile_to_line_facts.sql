with line_totals as (
    select
        order_id,
        sum(gross_amount) as gross_amount,
        sum(discount_amount) as discount_amount,
        sum(net_sales) as net_sales,
        sum(refund_amount) as refund_amount,
        sum(post_refund_revenue) as post_refund_revenue,
        sum(cost) as cost,
        sum(margin) as margin
    from {{ ref('fct_order_items') }}
    group by order_id
)

select
    orders.order_id
from {{ ref('fct_orders') }} as orders
inner join line_totals using (order_id)
where abs(orders.gross_amount - line_totals.gross_amount) > 0.01
   or abs(orders.discount_amount - line_totals.discount_amount) > 0.01
   or abs(orders.net_sales - line_totals.net_sales) > 0.01
   or abs(orders.refund_amount - line_totals.refund_amount) > 0.01
   or abs(orders.post_refund_revenue - line_totals.post_refund_revenue) > 0.01
   or abs(orders.cost - line_totals.cost) > 0.01
   or abs(orders.margin - line_totals.margin) > 0.01

