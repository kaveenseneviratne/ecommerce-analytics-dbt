-- The geolocation file has many coordinates per zip prefix and a few that land far outside
-- Brazil. Drop anything outside the country's bounding box, then average what's left into
-- one point per zip prefix that the dimensions can join to.

with

geolocation as (
    select * from {{ ref('stg_olist__geolocation') }}
),

inside_brazil as (
    select *
    from geolocation
    where
        latitude between -33.8 and 5.3
        and longitude between -73.99 and -34.79
)

select
    zip_code_prefix,
    avg(latitude) as latitude,
    avg(longitude) as longitude,
    count(*) as source_point_count
from inside_brazil
group by zip_code_prefix
