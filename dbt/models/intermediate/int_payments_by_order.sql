with payments as (
    select *
    from {{ ref('stg_payments') }}
),

aggregated as (
    select
        order_id,
        count(*)::integer as payment_attempt_count,
        count(*) filter (where payment_status = 'succeeded')::integer as successful_payment_count,
        coalesce(
            sum(amount) filter (where payment_status = 'succeeded'),
            0::numeric
        )::numeric(14, 2) as successful_paid_amount,
        max(greatest(updated_at, source_loaded_at)) as payment_updated_at
    from payments
    group by order_id
),

latest_payment as (
    select
        order_id,
        payment_status as latest_payment_status
    from (
        select
            order_id,
            payment_status,
            row_number() over (
                partition by order_id
                order by greatest(updated_at, source_loaded_at) desc, payment_id desc
            ) as payment_recency
        from payments
    ) ranked
    where payment_recency = 1
)

select
    aggregated.order_id,
    aggregated.payment_attempt_count,
    aggregated.successful_payment_count,
    aggregated.successful_paid_amount,
    latest_payment.latest_payment_status,
    aggregated.payment_updated_at
from aggregated
inner join latest_payment using (order_id)

