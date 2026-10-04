-- How many customers come back, and how long do they take? Uses LAG to measure the gap
-- between each customer's consecutive orders.

with

orders as (
    select
        customer_unique_id,
        order_id,
        purchased_at,
        customer_order_number,
        lag(purchased_at) over (
            partition by customer_unique_id
            order by purchased_at, order_id
        ) as previous_order_at
    from {{ ref('fct_orders') }}
    where is_valid_order
),

second_orders as (
    select
        customer_unique_id,
        {{ dbt.datediff(
            'previous_order_at',
            'purchased_at',
            'day'
        ) }} as days_to_second_order
    from orders
    where customer_order_number = 2
),

customers as (
    select * from {{ ref('dim_customers') }}
),

summary as (
    select
        count(*) as customers,
        sum(case when customers.is_repeat_customer then 1 else 0 end) as repeat_customers,
        avg(second_orders.days_to_second_order) as avg_days_to_second_order
    from customers
    left join second_orders
        on customers.customer_unique_id = second_orders.customer_unique_id
)

select
    customers,
    repeat_customers,
    {{ safe_divide('repeat_customers', 'customers') }} as repeat_rate,
    avg_days_to_second_order
from summary
