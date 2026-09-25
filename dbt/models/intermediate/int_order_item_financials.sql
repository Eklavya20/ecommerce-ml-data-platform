with order_items as (
    select *
    from {{ ref('stg_order_items') }}
),

products as (
    select
        product_id,
        unit_cost,
        updated_at,
        source_loaded_at
    from {{ ref('stg_products') }}
),

returns_by_item as (
    select *
    from {{ ref('int_returns_by_order_item') }}
),

joined as (
    select
        order_items.order_item_id,
        order_items.order_id,
        order_items.product_id,
        order_items.quantity,
        order_items.unit_price,
        order_items.discount_amount,
        coalesce(returns_by_item.returned_quantity, 0) as returned_quantity,
        coalesce(returns_by_item.refund_amount, 0::numeric) as refund_amount,
        coalesce(returns_by_item.return_event_count, 0) as return_event_count,
        products.unit_cost,
        greatest(
            order_items.updated_at,
            order_items.source_loaded_at,
            products.updated_at,
            products.source_loaded_at,
            coalesce(returns_by_item.return_updated_at, '1900-01-01'::timestamptz)
        ) as source_updated_at
    from order_items
    inner join products using (product_id)
    left join returns_by_item using (order_item_id)
),

calculated as (
    select
        *,
        (quantity * unit_price)::numeric(14, 2) as gross_amount,
        ((quantity * unit_price) - discount_amount)::numeric(14, 2) as net_sales,
        (quantity * unit_cost)::numeric(14, 2) as cost
    from joined
)

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
    discount_amount::numeric(14, 2) as discount_amount,
    net_sales,
    refund_amount::numeric(14, 2) as refund_amount,
    (net_sales - refund_amount)::numeric(14, 2) as post_refund_revenue,
    cost,
    (net_sales - refund_amount - cost)::numeric(14, 2) as margin,
    source_updated_at
from calculated

