with

source as (
    select * from {{ source('olist', 'products') }}
),

renamed as (
    select
        product_id,
        nullif(trim(product_category_name), '') as category_name_pt,
        -- the source spells "length" as "lenght"; fixed here so nothing downstream inherits it
        {{ to_int('product_name_lenght') }} as name_length,
        {{ to_int('product_description_lenght') }} as description_length,
        {{ to_int('product_photos_qty') }} as photo_count,
        cast(product_weight_g as {{ dbt.type_numeric() }}) as weight_g,
        cast(product_length_cm as {{ dbt.type_numeric() }}) as length_cm,
        cast(product_height_cm as {{ dbt.type_numeric() }}) as height_cm,
        cast(product_width_cm as {{ dbt.type_numeric() }}) as width_cm
    from source
)

select * from renamed
