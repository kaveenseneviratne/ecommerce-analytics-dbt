with

source as (
    select * from {{ source('olist', 'order_items') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key(['order_id', 'order_item_id']) }} as order_item_id,
        order_id,
        {{ to_int('order_item_id') }} as item_sequence,
        product_id,
        seller_id,
        cast(shipping_limit_date as {{ dbt.type_timestamp() }}) as shipping_limit_at,
        cast(price as {{ dbt.type_numeric() }}) as price,
        cast(freight_value as {{ dbt.type_numeric() }}) as freight_value
    from source
)

select * from renamed
