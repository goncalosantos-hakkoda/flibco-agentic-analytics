with routes as (
    select * from {{ ref('stg_routes') }}
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
from routes
