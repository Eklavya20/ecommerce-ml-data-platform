with orders as (
    select *
    from {{ ref('stg_orders') }}
),

order_item_totals as (
    select
        order_id,
        count(*)::integer as order_line_count,
        sum(quantity)::integer as units,
        sum(returned_quantity)::integer as returned_quantity,
        sum(gross_amount)::numeric(14, 2) as gross_amount,
        sum(discount_amount)::numeric(14, 2) as discount_amount,
        sum(net_sales)::numeric(14, 2) as net_sales,
        sum(refund_amount)::numeric(14, 2) as refund_amount,
        sum(post_refund_revenue)::numeric(14, 2) as post_refund_revenue,
        sum(cost)::numeric(14, 2) as cost,
        sum(margin)::numeric(14, 2) as margin,
        max(source_updated_at) as order_items_updated_at
    from {{ ref('int_order_item_financials') }}
    group by order_id
),

payments as (
    select *
    from {{ ref('int_payments_by_order') }}
)

select
    orders.order_id,
    orders.customer_id,
    orders.order_status,
    orders.sales_channel,
    orders.currency,
    orders.ordered_at,
    orders.updated_at as order_updated_at,
    order_item_totals.order_line_count,
    order_item_totals.units,
    order_item_totals.returned_quantity,
    order_item_totals.gross_amount,
    order_item_totals.discount_amount,
    order_item_totals.net_sales,
    order_item_totals.refund_amount,
    order_item_totals.post_refund_revenue,
    order_item_totals.cost,
    order_item_totals.margin,
    coalesce(payments.payment_attempt_count, 0) as payment_attempt_count,
    coalesce(payments.successful_payment_count, 0) as successful_payment_count,
    coalesce(payments.successful_paid_amount, 0::numeric)::numeric(14, 2) as successful_paid_amount,
    payments.latest_payment_status,
    greatest(
        orders.updated_at,
        orders.source_loaded_at,
        order_item_totals.order_items_updated_at,
        coalesce(payments.payment_updated_at, '1900-01-01'::timestamptz)
    ) as source_updated_at
from orders
inner join order_item_totals using (order_id)
left join payments using (order_id)
