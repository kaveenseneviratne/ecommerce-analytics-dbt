-- A calendar covering the dataset with some headroom. Joining reports to this instead of to
-- the order dates means months with no orders still show up as zero, not as a gap.

with

spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2016-01-01' as date)",
        end_date="cast('2019-01-01' as date)"
    ) }}
),

days as (
    select cast(date_day as date) as date_day from spine
)

select
    date_day,
    cast({{ dbt.date_trunc('month', 'date_day') }} as date) as month_start,
    cast({{ dbt.date_trunc('quarter', 'date_day') }} as date) as quarter_start,
    extract(year from date_day) as year_number,
    extract(quarter from date_day) as quarter_number,
    extract(month from date_day) as month_number,
    {{ iso_day_of_week('date_day') }} as iso_day_of_week,
    {{ iso_day_of_week('date_day') }} in (6, 7) as is_weekend
from days
