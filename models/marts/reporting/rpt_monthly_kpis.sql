-- Monthly business KPIs for the dashboard's overview page.

with

orders as (
    select * from {{ ref('fct_orders') }}
    where
        is_valid_order
        and order_date between cast('{{ var("reporting_start_date") }}' as date)
        and cast('{{ var("reporting_end_date") }}' as date)
),

months as (
    select distinct month_start
    from {{ ref('dim_dates') }}
    where
        date_day between cast('{{ var("reporting_start_date") }}' as date)
        and cast('{{ var("reporting_end_date") }}' as date)
),

monthly as (
    select
        cast({{ dbt.date_trunc('month', 'order_date') }} as date) as month_start,
        count(*) as orders,
        count(distinct customer_unique_id) as customers,
        sum(case when is_first_order then 1 else 0 end) as new_customers,
        sum(order_value) as revenue,
        sum(freight_value) as freight_revenue,
        sum(case when is_delivered then 1 else 0 end) as delivered_orders,
        sum(case when is_late then 1 else 0 end) as late_orders,
        avg(days_to_deliver) as avg_days_to_deliver,
        avg(review_score) as avg_review_score
    from orders
    group by cast({{ dbt.date_trunc('month', 'order_date') }} as date)
),

filled as (
    -- Start from the calendar so a month without orders shows as zero instead of
    -- silently disappearing and breaking month-over-month comparisons.
    select
        months.month_start,
        coalesce(monthly.orders, 0) as orders,
        coalesce(monthly.customers, 0) as customers,
        coalesce(monthly.new_customers, 0) as new_customers,
        coalesce(monthly.revenue, 0) as revenue,
        coalesce(monthly.freight_revenue, 0) as freight_revenue,
        coalesce(monthly.delivered_orders, 0) as delivered_orders,
        coalesce(monthly.late_orders, 0) as late_orders,
        monthly.avg_days_to_deliver,
        monthly.avg_review_score
    from months
    left join monthly on months.month_start = monthly.month_start
)

select
    month_start,
    orders,
    customers,
    new_customers,
    revenue,
    freight_revenue,
    {{ safe_divide('revenue', 'orders') }} as avg_order_value,
    delivered_orders,
    {{ safe_divide('late_orders', 'delivered_orders') }} as late_delivery_rate,
    avg_days_to_deliver,
    avg_review_score,
    {{ safe_divide(
        'revenue - lag(revenue) over (order by month_start)',
        'lag(revenue) over (order by month_start)'
    ) }} as revenue_growth_mom,
    sum(revenue) over (
        order by month_start
        rows between 2 preceding and current row
    ) as revenue_rolling_3m,
    sum(revenue) over (
        partition by extract(year from month_start)
        order by month_start
        rows between unbounded preceding and current row
    ) as revenue_ytd
from filled
