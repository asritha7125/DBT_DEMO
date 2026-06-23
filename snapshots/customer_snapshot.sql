{% snapshot customer_snapshot %}

{{
    config(
      target_schema='SNAPSHOTS',
      unique_key='customer_id',
      strategy='check',
      check_cols=['city']
    )
}}

select
    customer_id,
    customer_name,
    city,
    signup_date
from {{ source('DBT_PRACTICE', 'CUSTOMERS') }}

{% endsnapshot %}
