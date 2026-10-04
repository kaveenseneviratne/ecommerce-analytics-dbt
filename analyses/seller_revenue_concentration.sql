-- How concentrated is revenue? Share of revenue earned by the top 1%, 5%, 10% and 20% of
-- sellers. Compile with `dbt compile -s seller_revenue_concentration` and run the SQL in
-- target/compiled/ in your warehouse console.

with

sellers as (
    select
        seller_id,
        revenue,
        percent_rank() over (order by revenue desc) as revenue_percentile
    from {{ ref('rpt_seller_performance') }}
),

bands as (
    select 0.01 as top_share
    union all
    select 0.05
    union all
    select 0.10
    union all
    select 0.20
),

banded as (
    select
        bands.top_share,
        sum(case when sellers.revenue_percentile < bands.top_share then 1 else 0 end) as sellers,
        sum(
            case when sellers.revenue_percentile < bands.top_share then sellers.revenue else 0 end
        ) as revenue,
        sum(sellers.revenue) as total_revenue
    from bands
    cross join sellers
    group by bands.top_share
)

select
    top_share as top_seller_share,
    sellers,
    revenue,
    {{ safe_divide('revenue', 'total_revenue') }} as share_of_revenue
from banded
order by top_share
