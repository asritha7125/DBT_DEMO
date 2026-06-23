{{
    config(
        materialized='incremental',
        unique_key='product_history_key'
    )
}}

select
    md5(
        cast(product_id as varchar)
        || '-' ||
        cast(price as varchar)
        || '-' ||
        category
    ) as product_history_key,

    product_id,
    product_name,
    category,
    price,
    current_timestamp() as recorded_at

from {{ ref('stg_products') }}

{% if is_incremental() %}

where md5(
        cast(product_id as varchar)
        || '-' ||
        cast(price as varchar)
        || '-' ||
        category
    ) not in (
        select product_history_key
        from {{ this }}
    )

{% endif %}