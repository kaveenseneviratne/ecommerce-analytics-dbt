-- The project's headline question: how much does delivery timing drive review scores?
-- One row per delivery timeliness bucket.

with

orders as (
    select * from {{ ref('fct_orders') }}
    where
        is_delivered
        and review_score is not null
        and order_date between cast('{{ var("reporting_start_date") }}' as date)
        and cast('{{ var("reporting_end_date") }}' as date)
),

buckets as (
    select
        delivery_timeliness,
        count(*) as orders,
        avg(review_score) as avg_review_score,
        avg(case when review_score = 1 then 1.0 else 0.0 end) as one_star_rate,
        avg(case when review_score = 5 then 1.0 else 0.0 end) as five_star_rate,
        avg(delivery_delay_days) as avg_delay_days
    from orders
    group by delivery_timeliness
)

select
    delivery_timeliness,
    orders,
    {{ safe_divide('orders', 'sum(orders) over ()') }} as share_of_orders,
    avg_review_score,
    one_star_rate,
    five_star_rate,
    avg_delay_days
from buckets
