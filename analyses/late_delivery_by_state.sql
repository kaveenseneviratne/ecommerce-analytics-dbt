-- Where is late delivery worst? Late rate and average delay by customer state, ranked,
-- with each state's gap to the national rate.

with

orders as (
    select
        fct_orders.order_id,
        fct_orders.is_late,
        fct_orders.delivery_delay_days,
        fct_orders.review_score,
        dim_customers.state_code,
        dim_customers.region
    from {{ ref('fct_orders') }} as fct_orders
    inner join {{ ref('dim_customers') }} as dim_customers
        on fct_orders.customer_unique_id = dim_customers.customer_unique_id
    where fct_orders.is_delivered
),

by_state as (
    select
        state_code,
        region,
        count(*) as delivered_orders,
        avg(case when is_late then 1.0 else 0.0 end) as late_rate,
        avg(delivery_delay_days) as avg_delay_days,
        avg(review_score) as avg_review_score
    from orders
    group by state_code, region
    having count(*) >= 100
)

select
    *,
    late_rate - avg(late_rate) over () as late_rate_vs_average,
    rank() over (order by late_rate desc) as late_rate_rank
from by_state
order by late_rate_rank asc
