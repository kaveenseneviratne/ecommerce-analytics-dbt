-- Valid orders should be paid in full. Small overpayments are expected (card instalment
-- interest), so only underpayments of more than 1 BRL are flagged. A warning, not a failure:
-- this checks the source system, not our logic.

{{ config(severity='warn') }}

select
    order_id,
    order_value,
    total_paid,
    total_paid - order_value as difference
from {{ ref('fct_orders') }}
where
    is_valid_order
    and item_count > 0
    and total_paid < order_value - 1
