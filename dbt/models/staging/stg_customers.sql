select
    customer_id::bigint as customer_id,
    lower(trim(email))::text as email,
    upper(trim(country_code))::text as country_code,
    lower(trim(acquisition_channel))::text as acquisition_channel,
    created_at::timestamptz as created_at,
    updated_at::timestamptz as updated_at,
    _loaded_at::timestamptz as source_loaded_at
from {{ source('ecommerce', 'customers') }}

