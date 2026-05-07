with source as (
    select * from {{ ref('raw_scheduled_trips') }}
),

casted as (
    select
        scheduled_trip_id,
        trip_id,
        route_id,
        vehicle_id,
        cast(scheduled_departure_at as timestamp_ntz) as scheduled_departure_at,
        cast(scheduled_arrival_at as timestamp_ntz) as scheduled_arrival_at,
        lower(trim(service_type)) as service_type,
        schedule_version
    from source
),

-- Complex logic: derive scheduling metadata and validate temporal consistency
enriched as (
    select
        *,
        -- Derive expected travel duration from schedule
        datediff('minute', scheduled_departure_at, scheduled_arrival_at) as scheduled_duration_minutes,

        -- Classify time-of-day service window
        case
            when hour(scheduled_departure_at) between 5 and 8 then 'early_morning'
            when hour(scheduled_departure_at) between 9 and 11 then 'morning'
            when hour(scheduled_departure_at) between 12 and 14 then 'midday'
            when hour(scheduled_departure_at) between 15 and 17 then 'afternoon'
            when hour(scheduled_departure_at) between 18 and 20 then 'evening'
            else 'night'
        end as departure_window,

        -- Flag weekend vs weekday scheduling (different reliability patterns)
        case
            when dayofweek(scheduled_departure_at) in (0, 6) then true
            else false
        end as is_weekend_service,

        -- Derive schedule density: how many minutes between this and average slot spacing
        -- Higher density = more congested schedule = higher delay risk
        case
            when hour(scheduled_departure_at) between 7 and 9 then 'high'
            when hour(scheduled_departure_at) between 16 and 18 then 'high'
            when hour(scheduled_departure_at) between 10 and 15 then 'medium'
            else 'low'
        end as schedule_density,

        -- Extract schedule quarter for versioning analysis
        case
            when schedule_version like '%Q1%' then 1
            when schedule_version like '%Q2%' then 2
            when schedule_version like '%Q3%' then 3
            when schedule_version like '%Q4%' then 4
        end as schedule_quarter,

        cast(left(schedule_version, 4) as integer) as schedule_year

    from casted
),

-- Validate: scheduled arrival must be after departure, duration must be positive
validated as (
    select
        *,
        case
            when scheduled_duration_minutes <= 0 then true
            when scheduled_departure_at >= scheduled_arrival_at then true
            else false
        end as _is_invalid_schedule
    from enriched
)

select
    scheduled_trip_id,
    trip_id,
    route_id,
    vehicle_id,
    scheduled_departure_at,
    scheduled_arrival_at,
    scheduled_duration_minutes,
    service_type,
    departure_window,
    is_weekend_service,
    schedule_density,
    schedule_version,
    schedule_quarter,
    schedule_year,
    _is_invalid_schedule
from validated
