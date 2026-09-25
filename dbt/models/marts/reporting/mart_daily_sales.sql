select
    (ordered_at::date::text || '-' || sales_channel) as daily_sales_key,
    ordered_at::date as order_date,
    sales_channel,
    count(*)::integer as order_count,
    count(distinct customer_id)::integer as unique_customers,
    sum(units)::integer as units,
    sum(gross_amount)::numeric(16, 2) as gross_sales,
    sum(discount_amount)::numeric(16, 2) as discounts,
    sum(refund_amount)::numeric(16, 2) as refunds,
    sum(post_refund_revenue)::numeric(16, 2) as post_refund_revenue,
    sum(margin)::numeric(16, 2) as margin
from {{ ref('fct_orders') }}
where order_status in ('paid', 'completed')
group by ordered_at::date, sales_channel
