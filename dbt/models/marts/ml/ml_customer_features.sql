with cutoffs as (
    select *
    from {{ ref('ml_prediction_cutoffs') }}
),

order_base as (
    select
        order_id,
        customer_id,
        ordered_at::date as order_date,
        order_updated_at::date as order_updated_date,
        order_status
    from {{ ref('int_orders_enriched') }}
    where order_status in ('paid', 'completed')
),

qualifying_orders_as_of as (
    select
        cutoffs.prediction_cutoff_date,
        cutoffs.dataset_observation_end_date,
        orders.order_id,
        orders.customer_id,
        orders.order_date,
        orders.order_updated_date
    from cutoffs
    inner join order_base as orders
        on orders.order_date <= cutoffs.prediction_cutoff_date
       and orders.order_updated_date <= cutoffs.prediction_cutoff_date
    where exists (
        select 1
        from {{ ref('stg_payments') }} as payments
        where payments.order_id = orders.order_id
          and payments.payment_status = 'succeeded'
          and payments.attempted_at::date <= cutoffs.prediction_cutoff_date
          and payments.updated_at::date <= cutoffs.prediction_cutoff_date
    )
),

returns_by_item_as_of as (
    select
        cutoffs.prediction_cutoff_date,
        returns.order_item_id,
        sum(returns.return_quantity)::integer as returned_quantity,
        sum(returns.refund_amount)::numeric(14, 2) as refund_amount,
        max(returns.returned_at::date) as latest_return_date,
        max(returns.updated_at::date) as latest_return_updated_date
    from cutoffs
    inner join {{ ref('stg_returns') }} as returns
        on returns.returned_at::date <= cutoffs.prediction_cutoff_date
       and returns.updated_at::date <= cutoffs.prediction_cutoff_date
    group by cutoffs.prediction_cutoff_date, returns.order_item_id
),

order_lines_as_of as (
    select
        orders.prediction_cutoff_date,
        orders.dataset_observation_end_date,
        orders.customer_id,
        orders.order_id,
        orders.order_date,
        orders.order_updated_date,
        items.quantity,
        items.net_sales,
        items.discount_amount,
        coalesce(returns.returned_quantity, 0) as returned_quantity,
        coalesce(returns.refund_amount, 0::numeric) as refund_amount,
        returns.latest_return_date,
        returns.latest_return_updated_date
    from qualifying_orders_as_of as orders
    inner join {{ ref('fct_order_items') }} as items using (order_id)
    left join returns_by_item_as_of as returns
        on returns.prediction_cutoff_date = orders.prediction_cutoff_date
       and returns.order_item_id = items.order_item_id
),

orders_as_of as (
    select
        prediction_cutoff_date,
        dataset_observation_end_date,
        customer_id,
        order_id,
        order_date,
        order_updated_date,
        sum(quantity)::integer as units,
        sum(returned_quantity)::integer as returned_quantity,
        sum(net_sales)::numeric(16, 2) as net_sales,
        sum(discount_amount)::numeric(16, 2) as discount_amount,
        sum(refund_amount)::numeric(16, 2) as refund_amount,
        sum(net_sales - refund_amount)::numeric(16, 2) as post_refund_revenue,
        max(latest_return_date) as latest_return_date,
        max(latest_return_updated_date) as latest_return_updated_date
    from order_lines_as_of
    group by
        prediction_cutoff_date,
        dataset_observation_end_date,
        customer_id,
        order_id,
        order_date,
        order_updated_date
),

payment_metrics_90d as (
    select
        cutoffs.prediction_cutoff_date,
        orders.customer_id,
        (
            count(*) filter (where payments.payment_status = 'succeeded')::numeric
            / nullif(count(*), 0)
        )::numeric(10, 4) as successful_payment_rate_90d,
        max(payments.attempted_at::date) as latest_payment_attempt_date,
        max(payments.updated_at::date) as latest_payment_updated_date
    from cutoffs
    inner join {{ ref('stg_orders') }} as orders
        on orders.ordered_at::date > cutoffs.prediction_cutoff_date - 90
       and orders.ordered_at::date <= cutoffs.prediction_cutoff_date
    inner join {{ ref('stg_payments') }} as payments
        on payments.order_id = orders.order_id
       and payments.attempted_at::date <= cutoffs.prediction_cutoff_date
       and payments.updated_at::date <= cutoffs.prediction_cutoff_date
    group by cutoffs.prediction_cutoff_date, orders.customer_id
),

customer_features as (
    select
        orders.customer_id,
        orders.prediction_cutoff_date,
        max(orders.dataset_observation_end_date) as dataset_observation_end_date,
        (orders.prediction_cutoff_date - customers.created_at::date)::integer as customer_tenure_days,
        (orders.prediction_cutoff_date - max(orders.order_date))::integer as days_since_last_order,
        count(*) filter (
            where orders.order_date > orders.prediction_cutoff_date - 30
        )::integer as orders_last_30d,
        count(*) filter (
            where orders.order_date > orders.prediction_cutoff_date - 90
        )::integer as orders_last_90d,
        count(*)::integer as orders_lifetime_before_cutoff,
        coalesce(sum(orders.units) filter (
            where orders.order_date > orders.prediction_cutoff_date - 30
        ), 0)::integer as units_last_30d,
        coalesce(sum(orders.units) filter (
            where orders.order_date > orders.prediction_cutoff_date - 90
        ), 0)::integer as units_last_90d,
        coalesce(sum(orders.post_refund_revenue) filter (
            where orders.order_date > orders.prediction_cutoff_date - 30
        ), 0::numeric)::numeric(16, 2) as revenue_last_30d,
        coalesce(sum(orders.post_refund_revenue) filter (
            where orders.order_date > orders.prediction_cutoff_date - 90
        ), 0::numeric)::numeric(16, 2) as revenue_last_90d,
        sum(orders.post_refund_revenue)::numeric(16, 2) as lifetime_revenue_before_cutoff,
        coalesce(avg(orders.post_refund_revenue) filter (
            where orders.order_date > orders.prediction_cutoff_date - 90
        ), 0::numeric)::numeric(16, 2) as avg_order_value_90d,
        avg(orders.post_refund_revenue)::numeric(16, 2) as avg_order_value_lifetime,
        coalesce(
            count(*) filter (
                where orders.order_date > orders.prediction_cutoff_date - 90
                  and orders.discount_amount > 0
            )::numeric
            / nullif(count(*) filter (
                where orders.order_date > orders.prediction_cutoff_date - 90
            ), 0),
            0::numeric
        )::numeric(10, 4) as discount_usage_rate_90d,
        (
            count(*) filter (where orders.discount_amount > 0)::numeric
            / count(*)
        )::numeric(10, 4) as lifetime_discount_usage_rate,
        coalesce(sum(orders.returned_quantity) filter (
            where orders.order_date > orders.prediction_cutoff_date - 90
        ), 0)::integer as returned_quantity_90d,
        coalesce(
            sum(orders.returned_quantity) filter (
                where orders.order_date > orders.prediction_cutoff_date - 90
            )::numeric
            / nullif(sum(orders.units) filter (
                where orders.order_date > orders.prediction_cutoff_date - 90
            ), 0),
            0::numeric
        )::numeric(10, 4) as return_rate_90d,
        max(orders.order_date) as latest_feature_order_date,
        max(orders.order_updated_date) as latest_feature_order_updated_date,
        max(orders.latest_return_date) as latest_feature_return_date,
        max(orders.latest_return_updated_date) as latest_feature_return_updated_date
    from orders_as_of as orders
    inner join {{ ref('dim_customers') }} as customers using (customer_id)
    group by
        orders.customer_id,
        orders.prediction_cutoff_date,
        customers.created_at
)

select
    (features.customer_id::text || '-' || features.prediction_cutoff_date::text) as customer_cutoff_key,
    features.customer_id,
    features.prediction_cutoff_date,
    features.dataset_observation_end_date,
    features.customer_tenure_days,
    features.days_since_last_order,
    features.orders_last_30d,
    features.orders_last_90d,
    features.orders_lifetime_before_cutoff,
    features.units_last_30d,
    features.units_last_90d,
    features.revenue_last_30d,
    features.revenue_last_90d,
    features.lifetime_revenue_before_cutoff,
    features.avg_order_value_90d,
    features.avg_order_value_lifetime,
    features.discount_usage_rate_90d,
    features.lifetime_discount_usage_rate,
    features.returned_quantity_90d,
    features.return_rate_90d,
    coalesce(payments.successful_payment_rate_90d, 0::numeric)::numeric(10, 4)
        as successful_payment_rate_90d,
    features.latest_feature_order_date,
    features.latest_feature_order_updated_date,
    features.latest_feature_return_date,
    features.latest_feature_return_updated_date,
    payments.latest_payment_attempt_date as latest_feature_payment_attempt_date,
    payments.latest_payment_updated_date as latest_feature_payment_updated_date
from customer_features as features
left join payment_metrics_90d as payments
    on payments.customer_id = features.customer_id
   and payments.prediction_cutoff_date = features.prediction_cutoff_date
