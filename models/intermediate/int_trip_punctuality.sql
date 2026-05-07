-- int_trip_punctuality.sql
-- Joins scheduled trip data with actual trip execution and delay incidents
-- to produce a comprehensive punctuality assessment per trip.
--
-- Complex logic includes:
-- 1. Departure and arrival variance calculations
-- 2. OTP (On-Time Performance) classification with 5-min threshold
-- 3. Rolling vehicle reliability (window function over last 5 trips)
-- 4. Cascading delay propagation detection via LAG
-- 5. Travel time efficiency ratio (actual vs scheduled)
-- 6. Route-day aggregate delay context

with scheduled as (
    select * from {{ ref('stg_scheduled_trips') }}
    where _is_invalid_schedule = false
),

actual_trips as (
    select * from {{ ref('stg_trips') }}
    where trip_status = 'completed'
),

delay_incidents as (
    select * from {{ ref('stg_delay_incidents') }}
    where _is_invalid_record = false
),

routes as (
    select * from {{ ref('stg_routes') }}
),

-- Core join: scheduled vs actual, one row per trip
trip_comparison as (
    select
        s.scheduled_trip_id,
        s.trip_id,
        s.route_id,
        s.vehicle_id,
        s.scheduled_departure_at,
        s.scheduled_arrival_at,
        s.scheduled_duration_minutes,
        s.service_type,
        s.departure_window,
        s.is_weekend_service,
        s.schedule_density,
        a.departure_at as actual_departure_at,
        a.arrival_at as actual_arrival_at,
        a.passengers_onboard,
        r.route_name,
        r.distance_km,
        r.vehicle_type,

        -- Departure delay: positive = late, negative = early
        datediff('minute', s.scheduled_departure_at, a.departure_at) as departure_delay_minutes,

        -- Arrival delay: positive = late, negative = early
        datediff('minute', s.scheduled_arrival_at, a.arrival_at) as arrival_delay_minutes,

        -- Actual travel duration
        datediff('minute', a.departure_at, a.arrival_at) as actual_duration_minutes,

        -- Travel time efficiency: ratio of actual to scheduled duration
        -- >1.0 means trip took longer than planned
        round(
            datediff('minute', a.departure_at, a.arrival_at)
            / nullif(s.scheduled_duration_minutes, 0),
            3
        ) as travel_time_ratio,

        cast(a.departure_at as date) as trip_date

    from scheduled s
    inner join actual_trips a on s.trip_id = a.trip_id
    left join routes r on s.route_id = r.route_id
),

-- Aggregate delay incidents per trip (a trip may have multiple incidents)
trip_incidents_agg as (
    select
        trip_id,
        count(*) as incident_count,
        sum(delay_minutes) as total_incident_delay_minutes,
        max(delay_minutes) as max_single_delay_minutes,
        sum(passenger_delay_minutes) as total_passenger_delay_minutes,
        listagg(distinct delay_category, ', ') within group (order by delay_category) as delay_categories,
        listagg(distinct delay_domain, ', ') within group (order by delay_domain) as delay_domains,
        max(case when is_cascading then 1 else 0 end) as has_cascading_incident,
        max(computed_severity) as worst_severity
    from delay_incidents
    group by trip_id
),

-- Join incidents with trip comparison
with_incidents as (
    select
        tc.*,
        coalesce(di.incident_count, 0) as incident_count,
        coalesce(di.total_incident_delay_minutes, 0) as total_incident_delay_minutes,
        di.max_single_delay_minutes,
        coalesce(di.total_passenger_delay_minutes, 0) as total_passenger_delay_minutes,
        di.delay_categories,
        di.delay_domains,
        coalesce(di.has_cascading_incident, 0) = 1 as has_cascading_incident,
        di.worst_severity as incident_worst_severity
    from trip_comparison tc
    left join trip_incidents_agg di on tc.trip_id = di.trip_id
),

-- Window functions: vehicle reliability trends and cascading delay detection
with_vehicle_context as (
    select
        *,

        -- OTP classification: 5-minute threshold (industry standard)
        case
            when departure_delay_minutes <= 5 then true
            else false
        end as is_on_time_departure,

        case
            when arrival_delay_minutes <= 5 then true
            else false
        end as is_on_time_arrival,

        -- Composite on-time: both departure AND arrival within threshold
        case
            when departure_delay_minutes <= 5 and arrival_delay_minutes <= 5 then true
            else false
        end as is_on_time,

        -- Severity tier based on departure delay magnitude
        case
            when departure_delay_minutes <= 5 then 'on_time'
            when departure_delay_minutes <= 15 then 'minor_delay'
            when departure_delay_minutes <= 30 then 'moderate_delay'
            when departure_delay_minutes <= 60 then 'major_delay'
            else 'severe_delay'
        end as delay_severity,

        -- Rolling average delay for this vehicle over last 5 trips (vehicle reliability)
        avg(departure_delay_minutes) over (
            partition by vehicle_id
            order by actual_departure_at
            rows between 4 preceding and current row
        ) as vehicle_rolling_avg_delay_5trips,

        -- Was the previous trip on this vehicle also delayed? (cascade detection)
        lag(departure_delay_minutes) over (
            partition by vehicle_id
            order by actual_departure_at
        ) as prev_trip_delay_minutes,

        -- Time since previous trip on same vehicle (operational turnaround)
        datediff('minute',
            lag(actual_arrival_at) over (
                partition by vehicle_id
                order by actual_departure_at
            ),
            actual_departure_at
        ) as vehicle_turnaround_minutes,

        -- Rank this trip's delay within its route-day (worst delays stand out)
        rank() over (
            partition by route_id, trip_date
            order by departure_delay_minutes desc
        ) as delay_rank_on_route_day,

        -- Route-day average (contextual: was this a bad day for the route?)
        avg(departure_delay_minutes) over (
            partition by route_id, trip_date
        ) as route_day_avg_delay

    from with_incidents
),

-- Final enrichment: cascade probability and compound risk score
final as (
    select
        *,

        -- Cascade probability: if prev trip was delayed AND turnaround was short
        case
            when coalesce(prev_trip_delay_minutes, 0) > 10
                 and coalesce(vehicle_turnaround_minutes, 999) < 60
            then true
            else false
        end as is_probable_cascade,

        -- Compound delay risk score (0-100):
        -- Combines delay magnitude, recurrence, passenger impact, and vehicle reliability
        least(100, greatest(0,
            (departure_delay_minutes * 1.5)
            + (case when not is_on_time then 10 else 0 end)
            + (case when has_cascading_incident then 15 else 0 end)
            + (case when vehicle_rolling_avg_delay_5trips > 15 then 20 else 0 end)
            + (incident_count * 5)
        ))::integer as delay_risk_score

    from with_vehicle_context
)

select
    scheduled_trip_id,
    trip_id,
    route_id,
    vehicle_id,
    route_name,
    distance_km,
    vehicle_type,
    service_type,
    departure_window,
    is_weekend_service,
    schedule_density,
    scheduled_departure_at,
    scheduled_arrival_at,
    scheduled_duration_minutes,
    actual_departure_at,
    actual_arrival_at,
    actual_duration_minutes,
    departure_delay_minutes,
    arrival_delay_minutes,
    travel_time_ratio,
    is_on_time_departure,
    is_on_time_arrival,
    is_on_time,
    delay_severity,
    incident_count,
    total_incident_delay_minutes,
    max_single_delay_minutes,
    total_passenger_delay_minutes,
    delay_categories,
    delay_domains,
    has_cascading_incident,
    incident_worst_severity,
    vehicle_rolling_avg_delay_5trips,
    prev_trip_delay_minutes,
    vehicle_turnaround_minutes,
    is_probable_cascade,
    delay_rank_on_route_day,
    route_day_avg_delay,
    delay_risk_score,
    passengers_onboard,
    trip_date
from final
