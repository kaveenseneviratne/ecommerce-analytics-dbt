with

sellers as (
    select * from {{ ref('stg_olist__sellers') }}
),

states as (
    select * from {{ ref('brazil_states') }}
),

geo as (
    select * from {{ ref('int_geolocation__zip_centroids') }}
)

select
    sellers.seller_id,
    sellers.zip_code_prefix,
    sellers.city,
    sellers.state_code,
    states.state_name,
    states.region,
    geo.latitude,
    geo.longitude
from sellers
left join states on sellers.state_code = states.state_code
left join geo on sellers.zip_code_prefix = geo.zip_code_prefix
