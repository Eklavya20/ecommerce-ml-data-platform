with order_bounds as (
    select
        min(ordered_at::date) as first_order_date,
        max(ordered_at::date) as dataset_observation_end_date
    from {{ ref('stg_orders') }}
),

monthly_cutoffs as (
    select
        generated_cutoff::date as prediction_cutoff_date,
        order_bounds.first_order_date,
        order_bounds.dataset_observation_end_date
    from order_bounds
    cross join lateral generate_series(
        date_trunc('month', order_bounds.first_order_date) + interval '3 months',
        date_trunc('month', order_bounds.dataset_observation_end_date),
        interval '1 month'
    ) as generated_cutoff
)

select
    prediction_cutoff_date,
    first_order_date,
    dataset_observation_end_date,
    (prediction_cutoff_date + 30)::date as observation_end_date
from monthly_cutoffs
where prediction_cutoff_date >= first_order_date + 90
  and prediction_cutoff_date + 30 <= dataset_observation_end_date

