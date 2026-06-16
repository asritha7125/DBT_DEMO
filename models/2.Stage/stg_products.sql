select
    product_id,
    initcap(product_name) as product_name,
    upper(category) as category,
    cast(price as number(10,2)) as price
from {{ source('DBT_PRACTICE', 'PRODUCTS') }} 