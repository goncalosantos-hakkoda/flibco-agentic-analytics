with source as (
    select * from {{ ref('raw_routes') }}
)

select
    route_id,
    route_name,
    origin,
    destination,
    distance_km,
    vehicle_type,
    base_fare_eur,
    frequency_daily
from source
