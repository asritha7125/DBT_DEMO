select
    customer_id,
    initcap(customer_name) as customer_name,
    upper(city) as city,
    cast(signup_date as date) as signup_date
from {{ source('DBT_PRACTICE', 'CUSTOMERS') }}