with source as (
    select * from {{ ref('raw_trips') }}
)

select
    trip_id,
    route_id,
    vehicle_id,
    cast(departure_datetime as timestamp_ntz) as departure_at,
    cast(arrival_datetime as timestamp_ntz) as arrival_at,
    vehicle_capacity,
    passengers_onboard,
    trip_status
from source
