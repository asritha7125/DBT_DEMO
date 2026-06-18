select
    customer_id,
    customer_name,
    count(distinct order_id) as total_orders,
    sum(order_amount) as total_sales,
    round(avg(order_amount), 2) as avg_order_value
from {{ ref('inter_demo') }}
where status = 'COMPLETED'
group by
    customer_id,
    customer_name
    