with

source as (
    select * from {{ source('olist', 'geolocation') }}
),

renamed as (
    select
        lpad(trim(geolocation_zip_code_prefix), 5, '0') as zip_code_prefix,
        cast(geolocation_lat as {{ dbt.type_float() }}) as latitude,
        cast(geolocation_lng as {{ dbt.type_float() }}) as longitude,
        lower(trim(geolocation_city)) as city,
        upper(trim(geolocation_state)) as state_code
    from source
)

select * from renamed
