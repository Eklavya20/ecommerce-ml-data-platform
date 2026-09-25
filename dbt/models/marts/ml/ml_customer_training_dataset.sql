select
    features.*,
    (features.prediction_cutoff_date + 30)::date as observation_end_date,
    case
        when exists (
            select 1
            from {{ ref('stg_orders') }} as future_orders
            where future_orders.customer_id = features.customer_id
              and future_orders.order_status in ('paid', 'completed')
              and future_orders.ordered_at::date > features.prediction_cutoff_date
              and future_orders.ordered_at::date <= features.prediction_cutoff_date + 30
              and exists (
                  select 1
                  from {{ ref('stg_payments') }} as future_payments
                  where future_payments.order_id = future_orders.order_id
                    and future_payments.payment_status = 'succeeded'
                    and future_payments.attempted_at::date <= features.prediction_cutoff_date + 30
                    and future_payments.updated_at::date <= features.prediction_cutoff_date + 30
              )
        ) then 1
        else 0
    end::integer as repeat_purchase_30d
from {{ ref('ml_customer_features') }} as features
