-- One row per real customer (customer_unique_id), not per Olist customer_id, which changes
-- with every order.

with

customers as (
    select * from {{ ref('stg_olist__customers') }}
),

orders as (
    select * from {{ ref('fct_orders') }}
),

states as (
    select * from {{ ref('brazil_states') }}
),

geo as (
    select * from {{ ref('int_geolocation__zip_centroids') }}
),

-- Customers can move between orders; describe them by where their latest order went
latest_location as (
    select
        orders.customer_unique_id,
        customers.zip_code_prefix,
        customers.city,
        customers.state_code,
        row_number() over (
            partition by orders.customer_unique_id
            order by orders.purchased_at desc, orders.order_id desc
        ) as recency_rank
    from orders
    inner join customers on orders.customer_id = customers.customer_id
),

order_history as (
    select
        customer_unique_id,
        min(purchased_at) as first_order_at,
        max(purchased_at) as last_order_at,
        count(*) as order_count,
        sum(case when is_valid_order then 1 else 0 end) as valid_order_count,
        sum(case when is_valid_order then order_value else 0 end) as lifetime_value,
        avg(review_score) as avg_review_score
    from orders
    group by customer_unique_id
)

select
    order_history.customer_unique_id,
    latest_location.zip_code_prefix,
    latest_location.city,
    latest_location.state_code,
    states.state_name,
    states.region,
    geo.latitude,
    geo.longitude,
    order_history.first_order_at,
    order_history.last_order_at,
    order_history.order_count,
    order_history.valid_order_count,
    order_history.lifetime_value,
    order_history.avg_review_score,
    order_history.valid_order_count > 1 as is_repeat_customer
from order_history
inner join latest_location
    on
        order_history.customer_unique_id = latest_location.customer_unique_id
        and latest_location.recency_rank = 1
left join states on latest_location.state_code = states.state_code
left join geo on latest_location.zip_code_prefix = geo.zip_code_prefix
