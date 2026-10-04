-- Category view: what sells, what it costs to ship, and how customers rate it.

with

items as (
    select * from {{ ref('fct_order_items') }}
    where
        is_valid_order
        and order_date between cast('{{ var("reporting_start_date") }}' as date)
        and cast('{{ var("reporting_end_date") }}' as date)
),

products as (
    select * from {{ ref('dim_products') }}
),

category_orders as (
    select
        products.category_name,
        items.order_id,
        max(case when items.is_delivered then 1 else 0 end) as is_delivered,
        max(case when items.is_late then 1 else 0 end) as is_late,
        max(items.review_score) as review_score,
        sum(items.price) as revenue,
        sum(items.freight_value) as freight_value,
        count(*) as items
    from items
    inner join products on items.product_id = products.product_id
    group by products.category_name, items.order_id
),

stats as (
    select
        category_name,
        count(*) as orders,
        sum(items) as items_sold,
        sum(revenue) as revenue,
        {{ safe_divide('sum(revenue)', 'count(*)') }} as avg_order_revenue,
        {{ safe_divide('sum(freight_value)', 'sum(revenue)') }} as freight_to_price_ratio,
        {{ safe_divide('sum(is_late)', 'sum(is_delivered)') }} as late_delivery_rate,
        avg(review_score) as avg_review_score
    from category_orders
    group by category_name
)

select
    *,
    {{ safe_divide('revenue', 'sum(revenue) over ()') }} as share_of_revenue,
    rank() over (order by revenue desc) as revenue_rank
from stats
