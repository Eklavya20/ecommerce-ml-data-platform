select
    product_id,
    sku,
    product_name,
    category,
    list_price,
    unit_cost,
    is_active,
    created_at,
    updated_at
from {{ ref('stg_products') }}

