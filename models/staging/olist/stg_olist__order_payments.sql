with

source as (
    select * from {{ source('olist', 'order_payments') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key(['order_id', 'payment_sequential']) }} as payment_id,
        order_id,
        {{ to_int('payment_sequential') }} as payment_sequence,
        lower(trim(payment_type)) as payment_type,
        {{ to_int('payment_installments') }} as installments,
        cast(payment_value as {{ dbt.type_numeric() }}) as payment_value
    from source
)

select * from renamed
