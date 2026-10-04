with

products as (
    select * from {{ ref('stg_olist__products') }}
),

categories as (
    select * from {{ ref('stg_olist__product_categories') }}
)

select
    products.product_id,
    products.category_name_pt,
    -- Two categories have no English translation; fall back to the Portuguese name
    -- rather than lose them in reports.
    coalesce(categories.category_name, products.category_name_pt, 'unknown') as category_name,
    products.name_length,
    products.description_length,
    products.photo_count,
    products.weight_g,
    products.length_cm,
    products.height_cm,
    products.width_cm,
    products.length_cm * products.height_cm * products.width_cm as volume_cm3
from products
left join categories on products.category_name_pt = categories.category_name_pt
