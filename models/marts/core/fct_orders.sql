with

orders as (
    select * from {{ ref('stg_olist__orders') }}
),

customers as (
    select * from {{ ref('stg_olist__customers') }}
),

items as (
    select * from {{ ref('int_order_items__aggregated_to_orders') }}
),

payments as (
    select * from {{ ref('int_payments__aggregated_to_orders') }}
),

reviews as (
    select * from {{ ref('int_reviews__latest_by_order') }}
),

joined as (
    select
        orders.order_id,
        orders.customer_id,
        customers.customer_unique_id,
        orders.order_status,

        orders.purchased_at,
        cast(orders.purchased_at as date) as order_date,
        orders.approved_at,
        orders.shipped_at,
        orders.delivered_at,
        orders.estimated_delivery_at,

        coalesce(items.item_count, 0) as item_count,
        coalesce(items.distinct_seller_count, 0) as distinct_seller_count,
        coalesce(items.items_value, 0) as items_value,
        coalesce(items.freight_value, 0) as freight_value,
        coalesce(items.items_value, 0) + coalesce(items.freight_value, 0) as order_value,

        payments.total_paid,
        payments.payment_count,
        payments.primary_payment_type,
        payments.max_installments,

        reviews.review_score,

        -- Canceled and unavailable orders never turned into revenue
        orders.order_status not in ('canceled', 'unavailable') as is_valid_order,
        orders.order_status = 'delivered' and orders.delivered_at is not null as is_delivered
    from orders
    left join customers on orders.customer_id = customers.customer_id
    left join items on orders.order_id = items.order_id
    left join payments on orders.order_id = payments.order_id
    left join reviews on orders.order_id = reviews.order_id
),

delivery as (
    select
        *,
        case
            when is_delivered
                then {{ dbt.datediff('purchased_at', 'delivered_at', 'day') }}
        end as days_to_deliver,
        -- Positive means late. Compared as dates because the estimate is a calendar day.
        case
            when is_delivered
                then {{ dbt.datediff(
                    'cast(estimated_delivery_at as date)',
                    'cast(delivered_at as date)',
                    'day'
                ) }}
        end as delivery_delay_days
    from joined
),

final as (
    select
        *,
        case when is_delivered then delivery_delay_days > 0 end as is_late,
        case
            when not is_delivered then 'Not delivered'
            when delivery_delay_days < -14 then '1. 15+ days early'
            when delivery_delay_days < -7 then '2. 8-14 days early'
            when delivery_delay_days < 0 then '3. 1-7 days early'
            when delivery_delay_days = 0 then '4. On the day'
            when delivery_delay_days <= 3 then '5. 1-3 days late'
            when delivery_delay_days <= 7 then '6. 4-7 days late'
            else '7. 8+ days late'
        end as delivery_timeliness,
        row_number() over (
            partition by customer_unique_id
            order by purchased_at, order_id
        ) as customer_order_number
    from delivery
)

select
    *,
    customer_order_number = 1 as is_first_order
from final
