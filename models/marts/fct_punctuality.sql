-- fct_punctuality.sql
-- Fact table for trip punctuality analysis. Grain: one row per trip.
-- Complex logic:
-- 1. Joins with dim_delay_categories to get SLA breach detection
-- 2. Computes percentile-based delay benchmarks per route
-- 3. Derives compound on-time performance indicators
-- 4. Calculates cost-of-delay estimates based on passengers and delay duration

{{
    config(
        materialized='table'
    )
}}

with punctuality as (
    select * from {{ ref('int_trip_punctuality') }}
),

delay_dim as (
    select * from {{ ref('dim_delay_categories') }}
),

delay_incidents as (
    select
        trip_id,
        delay_category,
        delay_minutes
    from {{ ref('stg_delay_incidents') }}
    where _is_invalid_record = false
),

-- Get the primary (worst) delay category per trip for dimension lookup
primary_delay_per_trip as (
    select
        trip_id,
        delay_category,
        row_number() over (
            partition by trip_id
            order by delay_minutes desc
        ) as rn
    from delay_incidents
),

-- Route-level percentile benchmarks for contextual scoring
route_benchmarks as (
    select
        route_id,
        percentile_cont(0.50) within group (order by departure_delay_minutes) as p50_departure_delay,
        percentile_cont(0.75) within group (order by departure_delay_minutes) as p75_departure_delay,
        percentile_cont(0.90) within group (order by departure_delay_minutes) as p90_departure_delay,
        percentile_cont(0.95) within group (order by departure_delay_minutes) as p95_departure_delay,
        avg(departure_delay_minutes) as route_avg_departure_delay,
        stddev(departure_delay_minutes) as route_stddev_departure_delay
    from punctuality
    group by route_id
),

-- Join everything together
combined as (
    select
        p.trip_id,
        p.route_id,
        p.vehicle_id,
        cast(p.trip_date as date) as date_key,
        p.route_name,
        p.vehicle_type,
        p.service_type,
        p.departure_window,
        p.is_weekend_service,
        p.schedule_density,

        -- Schedule timestamps
        p.scheduled_departure_at,
        p.scheduled_arrival_at,
        p.scheduled_duration_minutes,

        -- Actual timestamps
        p.actual_departure_at,
        p.actual_arrival_at,
        p.actual_duration_minutes,

        -- Core delay metrics
        p.departure_delay_minutes,
        p.arrival_delay_minutes,
        p.travel_time_ratio,

        -- OTP flags
        p.is_on_time_departure,
        p.is_on_time_arrival,
        p.is_on_time,
        p.delay_severity,

        -- Incident metrics
        p.incident_count,
        p.total_incident_delay_minutes,
        p.max_single_delay_minutes,
        p.total_passenger_delay_minutes,
        p.delay_categories,
        p.delay_domains,
        p.has_cascading_incident,
        p.incident_worst_severity,

        -- Vehicle reliability context
        p.vehicle_rolling_avg_delay_5trips,
        p.is_probable_cascade,
        p.vehicle_turnaround_minutes,

        -- Risk score
        p.delay_risk_score,

        -- Passengers
        p.passengers_onboard,

        -- Delay dimension FK (primary delay category for this trip)
        pd.delay_category as primary_delay_category,
        dd.delay_category_key,
        dd.controllability as delay_controllability,
        dd.sla_threshold_minutes,

        -- SLA breach detection: delay exceeds the category's SLA threshold
        case
            when pd.delay_category is not null
                 and p.departure_delay_minutes > dd.sla_threshold_minutes
            then true
            else false
        end as is_sla_breach,

        -- Route percentile context: how does this trip compare to its route's distribution
        rb.p50_departure_delay as route_p50_delay,
        rb.p75_departure_delay as route_p75_delay,
        rb.p90_departure_delay as route_p90_delay,
        rb.route_avg_departure_delay,

        -- Percentile rank of this trip within its route
        case
            when p.departure_delay_minutes <= rb.p50_departure_delay then 'below_median'
            when p.departure_delay_minutes <= rb.p75_departure_delay then 'p50_to_p75'
            when p.departure_delay_minutes <= rb.p90_departure_delay then 'p75_to_p90'
            else 'above_p90'
        end as route_delay_percentile_band,

        -- Z-score: how many standard deviations from route mean
        case
            when rb.route_stddev_departure_delay > 0
            then round(
                (p.departure_delay_minutes - rb.route_avg_departure_delay)
                / rb.route_stddev_departure_delay,
                2
            )
            else 0
        end as delay_z_score,

        -- Estimated cost-of-delay: EUR 0.50 per passenger-delay-minute
        -- (accounts for compensation, reputation damage, missed connections)
        round(
            greatest(0, p.departure_delay_minutes - 5)  -- only count minutes beyond threshold
            * p.passengers_onboard
            * 0.50,
            2
        ) as estimated_delay_cost_eur

    from punctuality p
    left join primary_delay_per_trip pd
        on p.trip_id = pd.trip_id and pd.rn = 1
    left join delay_dim dd
        on pd.delay_category = dd.delay_category
    left join route_benchmarks rb
        on p.route_id = rb.route_id
)

select * from combined
