with

order_items as (
    select * from {{ ref('stg_olist__order_items') }}
),

orders as (
    select * from {{ ref('fct_orders') }}
)

select
    order_items.order_item_id,
    order_items.order_id,
    order_items.item_sequence,
    order_items.product_id,
    order_items.seller_id,
    orders.customer_unique_id,
    orders.order_date,
    orders.order_status,
    orders.is_valid_order,
    orders.is_delivered,
    orders.is_late,
    orders.review_score,
    order_items.shipping_limit_at,
    order_items.price,
    order_items.freight_value,
    order_items.price + order_items.freight_value as item_value
from order_items
inner join orders on order_items.order_id = orders.order_id
