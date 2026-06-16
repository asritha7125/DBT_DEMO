select
    order_id,
    customer_id,
    product_id,
    cast(order_date as date) as order_date,
    quantity,
    upper(status) as status
from {{ source('DBT_PRACTICE', 'ORDERS') }}