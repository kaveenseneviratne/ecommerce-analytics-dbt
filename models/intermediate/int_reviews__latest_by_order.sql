-- Some orders were reviewed more than once. Keep the most recent review, since that's the
-- customer's final word; ties fall back to review_id so the result is deterministic.

with

reviews as (
    select * from {{ ref('stg_olist__order_reviews') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by order_id
            order by review_answered_at desc nulls last, review_created_at desc, review_id asc
        ) as review_rank
    from reviews
)

select
    order_id,
    review_id,
    review_score,
    comment_title,
    comment_message,
    review_created_at,
    review_answered_at
from ranked
where review_rank = 1
