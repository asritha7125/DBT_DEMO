select
    o.order_id,
    o.customer_id,
    c.customer_name,
    c.city,
    o.product_id, 
    p.product_name,
    p.category,
    o.order_date,
    o.quantity,
    p.price,
    o.quantity * p.price as order_amount,
    o.status
from {{ ref('stg_orders') }} o
left join {{ ref('stg_customers') }} c
    on o.customer_id = c.customer_id
left join {{ ref('stg_products') }} p
    on o.product_id = p.product_id