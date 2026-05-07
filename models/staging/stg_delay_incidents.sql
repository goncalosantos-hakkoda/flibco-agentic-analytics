with source as (
    select * from {{ ref('raw_delay_incidents') }}
),

casted as (
    select
        incident_id,
        trip_id,
        route_id,
        lower(trim(delay_category)) as delay_category,
        cast(delay_minutes as integer) as delay_minutes,
        lower(trim(impact_level)) as impact_level,
        cast(reported_at as timestamp_ntz) as reported_at,
        cast(resolved_at as timestamp_ntz) as resolved_at,
        cast(is_cascading as boolean) as is_cascading,
        cast(affected_passengers as integer) as affected_passengers
    from source
),

-- Complex logic: derive incident resolution metrics and classify delay severity
enriched as (
    select
        *,
        -- Resolution time in minutes
        datediff('minute', reported_at, resolved_at) as resolution_minutes,

        -- Reclassify severity using a more granular scale based on delay + passenger impact
        -- Compound severity considers both duration AND number of affected passengers
        case
            when delay_minutes > 40 and affected_passengers > 30 then 'critical'
            when delay_minutes > 30 or (delay_minutes > 20 and affected_passengers > 25) then 'severe'
            when delay_minutes > 15 or (delay_minutes > 10 and affected_passengers > 20) then 'moderate'
            when delay_minutes > 5 then 'minor'
            else 'negligible'
        end as computed_severity,

        -- Passenger-delay-minutes: total disruption impact metric
        -- This composite metric captures the full "cost" of a delay
        delay_minutes * affected_passengers as passenger_delay_minutes,

        -- Categorize the root cause domain for upstream analytics
        case
            when delay_category in ('traffic_congestion', 'road_closure') then 'infrastructure'
            when delay_category in ('weather_conditions') then 'environmental'
            when delay_category in ('mechanical_issue') then 'fleet'
            when delay_category in ('passenger_boarding', 'security_check') then 'passenger_ops'
            when delay_category in ('operational_handover') then 'internal_ops'
            else 'unknown'
        end as delay_domain,

        -- Flag if resolution was rapid (under 15 min) vs prolonged
        case
            when datediff('minute', reported_at, resolved_at) <= 15 then 'rapid'
            when datediff('minute', reported_at, resolved_at) <= 45 then 'standard'
            else 'prolonged'
        end as resolution_category,

        -- Time-of-day when incident occurred (for pattern analysis)
        case
            when hour(reported_at) between 6 and 9 then 'morning_rush'
            when hour(reported_at) between 10 and 15 then 'midday'
            when hour(reported_at) between 16 and 19 then 'evening_rush'
            else 'off_peak'
        end as incident_time_band,

        -- Flag anomalous incidents: resolution faster than delay itself (data quality check)
        case
            when datediff('minute', reported_at, resolved_at) < delay_minutes * 0.5 then true
            else false
        end as _is_rapid_resolution_anomaly

    from casted
),

-- Validate: delay_minutes must be positive, resolution must be after report
validated as (
    select
        *,
        case
            when delay_minutes <= 0 then true
            when resolved_at < reported_at then true
            else false
        end as _is_invalid_record
    from enriched
)

select
    incident_id,
    trip_id,
    route_id,
    delay_category,
    delay_domain,
    delay_minutes,
    impact_level,
    computed_severity,
    passenger_delay_minutes,
    reported_at,
    resolved_at,
    resolution_minutes,
    resolution_category,
    incident_time_band,
    is_cascading,
    affected_passengers,
    _is_rapid_resolution_anomaly,
    _is_invalid_record
from validated
