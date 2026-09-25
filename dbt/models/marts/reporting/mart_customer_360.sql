with commercial_orders as (
    select *
    from {{ ref('fct_orders') }}
    where order_status in ('paid', 'completed')
),

customer_order_metrics as (
    select
        customer_id,
        count(*)::integer as total_orders,
        sum(units)::integer as total_units,
        sum(returned_quantity)::integer as returned_quantity,
        sum(gross_amount)::numeric(16, 2) as gross_sales,
        sum(discount_amount)::numeric(16, 2) as discounts,
        sum(net_sales)::numeric(16, 2) as net_sales,
        sum(refund_amount)::numeric(16, 2) as refunds,
        sum(post_refund_revenue)::numeric(16, 2) as post_refund_revenue,
        sum(margin)::numeric(16, 2) as margin,
        avg(post_refund_revenue)::numeric(16, 2) as average_order_value,
        min(ordered_at)::date as first_order_date,
        max(ordered_at)::date as latest_order_date,
        (current_date - max(ordered_at)::date)::integer as recency_days,
        count(*)::integer as frequency,
        count(*) filter (where discount_amount > 0)::integer as discounted_order_count,
        count(*) filter (where refund_amount > 0)::integer as returned_order_count
    from commercial_orders
    group by customer_id
),

customer_line_metrics as (
    select
        commercial_orders.customer_id,
        count(distinct order_items.product_id)::integer as distinct_products_purchased,
        sum(order_items.return_event_count)::integer as return_event_count
    from commercial_orders
    inner join {{ ref('fct_order_items') }} as order_items using (order_id)
    group by commercial_orders.customer_id
)

select
    customers.customer_id,
    customers.email,
    customers.country_code,
    customers.acquisition_channel,
    coalesce(order_metrics.total_orders, 0) as total_orders,
    coalesce(order_metrics.total_units, 0) as total_units,
    coalesce(order_metrics.returned_quantity, 0) as returned_quantity,
    coalesce(order_metrics.gross_sales, 0::numeric)::numeric(16, 2) as gross_sales,
    coalesce(order_metrics.discounts, 0::numeric)::numeric(16, 2) as discounts,
    coalesce(order_metrics.net_sales, 0::numeric)::numeric(16, 2) as net_sales,
    coalesce(order_metrics.refunds, 0::numeric)::numeric(16, 2) as refunds,
    coalesce(order_metrics.post_refund_revenue, 0::numeric)::numeric(16, 2) as post_refund_revenue,
    coalesce(order_metrics.margin, 0::numeric)::numeric(16, 2) as margin,
    coalesce(order_metrics.average_order_value, 0::numeric)::numeric(16, 2) as average_order_value,
    order_metrics.first_order_date,
    order_metrics.latest_order_date,
    order_metrics.recency_days,
    coalesce(order_metrics.frequency, 0) as frequency,
    coalesce(order_metrics.discounted_order_count, 0) as discounted_order_count,
    coalesce(order_metrics.returned_order_count, 0) as returned_order_count,
    coalesce(line_metrics.distinct_products_purchased, 0) as distinct_products_purchased,
    coalesce(line_metrics.return_event_count, 0) as return_event_count,
    case
        when coalesce(order_metrics.total_units, 0) = 0 then 0::numeric
        else (order_metrics.returned_quantity::numeric / order_metrics.total_units)::numeric(10, 4)
    end as unit_return_rate
from {{ ref('dim_customers') }} as customers
left join customer_order_metrics as order_metrics using (customer_id)
left join customer_line_metrics as line_metrics using (customer_id)

