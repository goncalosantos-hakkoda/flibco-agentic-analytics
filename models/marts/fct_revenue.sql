with booking_revenue as (
    select * from {{ ref('int_booking_revenue') }}
)

select
    booking_id,
    trip_id,
    route_id,
    cast(booking_date as date) as date_key,
    booked_at,
    passengers,
    fare_per_passenger,
    total_fare,
    payment_method,
    booking_status,
    channel
from booking_revenue
