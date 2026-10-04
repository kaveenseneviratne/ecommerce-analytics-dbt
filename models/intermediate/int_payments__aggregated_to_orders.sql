with

payments as (
    select * from {{ ref('stg_olist__order_payments') }}
),

-- The method that covered the most money is the order's "primary" payment type
primary_method as (
    select
        order_id,
        payment_type as primary_payment_type,
        row_number() over (
            partition by order_id
            order by payment_value desc, payment_sequence asc
        ) as method_rank
    from payments
),

totals as (
    select
        order_id,
        count(*) as payment_count,
        sum(payment_value) as total_paid,
        sum(case when payment_type = 'voucher' then payment_value else 0 end) as voucher_paid,
        max(installments) as max_installments
    from payments
    group by order_id
)

select
    totals.order_id,
    totals.payment_count,
    totals.total_paid,
    totals.voucher_paid,
    totals.max_installments,
    primary_method.primary_payment_type
from totals
inner join primary_method
    on
        totals.order_id = primary_method.order_id
        and primary_method.method_rank = 1
