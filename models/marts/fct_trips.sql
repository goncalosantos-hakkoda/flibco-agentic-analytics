with trip_occupancy as (
    select * from {{ ref('int_trip_occupancy') }}
)

select
    trip_id,
    route_id,
    vehicle_id,
    cast(trip_date as date) as date_key,
    departure_at,
    arrival_at,
    vehicle_capacity,
    passengers_onboard,
    occupancy_rate,
    trip_status
from trip_occupancy
