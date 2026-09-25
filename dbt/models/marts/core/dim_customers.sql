select
    customer_id,
    email,
    country_code,
    acquisition_channel,
    created_at,
    updated_at
from {{ ref('stg_customers') }}

