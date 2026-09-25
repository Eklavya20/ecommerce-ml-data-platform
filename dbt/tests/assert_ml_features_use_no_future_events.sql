select
    customer_id,
    prediction_cutoff_date,
    latest_feature_order_date,
    latest_feature_order_updated_date,
    latest_feature_return_date,
    latest_feature_return_updated_date,
    latest_feature_payment_attempt_date,
    latest_feature_payment_updated_date
from {{ ref('ml_customer_features') }}
where latest_feature_order_date > prediction_cutoff_date
   or latest_feature_order_updated_date > prediction_cutoff_date
   or latest_feature_return_date > prediction_cutoff_date
   or latest_feature_return_updated_date > prediction_cutoff_date
   or latest_feature_payment_attempt_date > prediction_cutoff_date
   or latest_feature_payment_updated_date > prediction_cutoff_date
