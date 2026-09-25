{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='delete+insert',
        on_schema_change='fail'
    )
}}

select
    order_id,
    customer_id,
    order_status,
    sales_channel,
    currency,
    ordered_at,
    order_line_count,
    units,
    returned_quantity,
    gross_amount,
    discount_amount,
    net_sales,
    refund_amount,
    post_refund_revenue,
    cost,
    margin,
    payment_attempt_count,
    successful_payment_count,
    successful_paid_amount,
    latest_payment_status,
    source_updated_at
from {{ ref('int_orders_enriched') }}
{% if is_incremental() %}
where source_updated_at >= (
    select coalesce(max(source_updated_at), '1900-01-01'::timestamptz) - interval '3 days'
    from {{ this }}
)
{% endif %}

