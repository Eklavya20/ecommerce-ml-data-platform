select
    customer_id,
    prediction_cutoff_date,
    observation_end_date,
    dataset_observation_end_date
from {{ ref('ml_customer_training_dataset') }}
where observation_end_date > dataset_observation_end_date

