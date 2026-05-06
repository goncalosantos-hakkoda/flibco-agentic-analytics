with bookings as (
    select * from {{ ref('stg_bookings') }}
),

routes as (
    select * from {{ ref('stg_routes') }}
)

select
    b.booking_id,
    b.trip_id,
    b.route_id,
    r.route_name,
    r.origin,
    r.destination,
    b.booked_at,
    cast(b.booked_at as date) as booking_date,
    b.passengers,
    b.fare_per_passenger,
    b.total_fare,
    b.payment_method,
    b.booking_status,
    b.channel
from bookings b
left join routes r on b.route_id = r.route_id
