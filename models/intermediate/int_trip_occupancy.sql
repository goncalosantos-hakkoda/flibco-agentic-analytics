with trips as (
    select * from {{ ref('stg_trips') }}
),

routes as (
    select * from {{ ref('stg_routes') }}
)

select
    t.trip_id,
    t.route_id,
    r.route_name,
    r.origin,
    r.destination,
    t.vehicle_id,
    t.departure_at,
    t.arrival_at,
    t.vehicle_capacity,
    t.passengers_onboard,
    round(t.passengers_onboard / nullif(t.vehicle_capacity, 0), 4) as occupancy_rate,
    t.trip_status,
    cast(t.departure_at as date) as trip_date
from trips t
left join routes r on t.route_id = r.route_id
where t.trip_status = 'completed'
