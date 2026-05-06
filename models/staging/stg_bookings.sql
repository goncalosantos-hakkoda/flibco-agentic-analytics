with source as (
    select * from {{ ref('raw_bookings') }}
)

select
    booking_id,
    trip_id,
    route_id,
    cast(booking_datetime as timestamp_ntz) as booked_at,
    passengers,
    fare_per_passenger,
    total_fare,
    payment_method,
    booking_status,
    channel
from source
