select
    product_id::bigint as product_id,
    upper(trim(sku))::text as sku,
    trim(product_name)::text as product_name,
    lower(trim(category))::text as category,
    list_price::numeric(12, 2) as list_price,
    unit_cost::numeric(12, 2) as unit_cost,
    is_active::boolean as is_active,
    created_at::timestamptz as created_at,
    updated_at::timestamptz as updated_at,
    _loaded_at::timestamptz as source_loaded_at
from {{ source('ecommerce', 'products') }}

