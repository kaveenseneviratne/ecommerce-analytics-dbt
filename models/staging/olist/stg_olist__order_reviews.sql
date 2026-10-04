with

source as (
    select * from {{ source('olist', 'order_reviews') }}
),

renamed as (
    select
        -- review_id alone isn't unique in the raw export, so the key combines both ids
        {{ dbt_utils.generate_surrogate_key(['review_id', 'order_id']) }} as order_review_id,
        review_id,
        order_id,
        {{ to_int('review_score') }} as review_score,
        nullif(trim(review_comment_title), '') as comment_title,
        nullif(trim(review_comment_message), '') as comment_message,
        cast(review_creation_date as {{ dbt.type_timestamp() }}) as review_created_at,
        cast(review_answer_timestamp as {{ dbt.type_timestamp() }}) as review_answered_at
    from source
)

select * from renamed
