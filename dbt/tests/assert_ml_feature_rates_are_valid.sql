select
    customer_id,
    prediction_cutoff_date
from {{ ref('ml_customer_features') }}
where discount_usage_rate_90d not between 0 and 1
   or lifetime_discount_usage_rate not between 0 and 1
   or return_rate_90d not between 0 and 1
   or successful_payment_rate_90d not between 0 and 1

