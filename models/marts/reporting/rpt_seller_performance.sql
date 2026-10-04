-- Seller scorecard: revenue ranking, concentration, and a flag for sellers whose
-- delivery or review record needs attention.

with

items as (
    select * from {{ ref('fct_order_items') }}
    where
        is_valid_order
        and order_date between cast('{{ var("reporting_start_date") }}' as date)
        and cast('{{ var("reporting_end_date") }}' as date)
),

sellers as (
    select * from {{ ref('dim_sellers') }}
),

-- An order can contain several items from the same seller. Collapse to one row per
-- seller and order first, so delivery and review stats count each order once.
seller_orders as (
    select
        seller_id,
        order_id,
        max(case when is_delivered then 1 else 0 end) as is_delivered,
        max(case when is_late then 1 else 0 end) as is_late,
        max(review_score) as review_score,
        sum(price) as revenue,
        count(*) as items
    from items
    group by seller_id, order_id
),

stats as (
    select
        seller_id,
        count(*) as orders,
        sum(items) as items_sold,
        sum(revenue) as revenue,
        sum(is_delivered) as delivered_orders,
        {{ safe_divide('sum(is_late)', 'sum(is_delivered)') }} as late_delivery_rate,
        avg(review_score) as avg_review_score
    from seller_orders
    group by seller_id
),

ranked as (
    select
        stats.*,
        sellers.state_code,
        sellers.region,
        rank() over (order by stats.revenue desc) as revenue_rank,
        rank() over (
            partition by sellers.state_code order by stats.revenue desc
        ) as revenue_rank_in_state,
        {{ safe_divide(
            'sum(stats.revenue) over (
                order by stats.revenue desc, stats.seller_id
                rows between unbounded preceding and current row
            )',
            'sum(stats.revenue) over ()'
        ) }} as cumulative_revenue_share,
        ntile(4) over (order by stats.revenue desc) as revenue_quartile
    from stats
    left join sellers on stats.seller_id = sellers.seller_id
)

select
    *,
    -- coalesce so sellers with no delivered or reviewed orders get false, not null
    orders >= {{ var('min_seller_orders') }}
    and (
        coalesce(late_delivery_rate > {{ var('seller_late_rate_alert') }}, false)
        or coalesce(avg_review_score < {{ var('seller_review_alert') }}, false)
    ) as needs_attention
from ranked
