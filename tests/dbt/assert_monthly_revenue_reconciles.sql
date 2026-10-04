-- Revenue in the reporting table must equal revenue in the fact table for the same window.
-- If the monthly rollup ever drops or double-counts orders, this fails the build.

with

fact_total as (
    select sum(order_value) as revenue
    from {{ ref('fct_orders') }}
    where
        is_valid_order
        and order_date between cast('{{ var("reporting_start_date") }}' as date)
        and cast('{{ var("reporting_end_date") }}' as date)
),

report_total as (
    select sum(revenue) as revenue
    from {{ ref('rpt_monthly_kpis') }}
)

select
    fact_total.revenue as fact_revenue,
    report_total.revenue as report_revenue
from fact_total
cross join report_total
where abs(coalesce(fact_total.revenue, 0) - coalesce(report_total.revenue, 0)) > 0.01
