with

order_items as (
    select * from {{ ref('stg_olist__order_items') }}
)

select
    order_id,
    count(*) as item_count,
    count(distinct product_id) as distinct_product_count,
    count(distinct seller_id) as distinct_seller_count,
    sum(price) as items_value,
    sum(freight_value) as freight_value
from order_items
group by order_id
