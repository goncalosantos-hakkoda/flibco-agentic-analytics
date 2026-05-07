-- dim_delay_categories.sql
-- Dimension table for delay categorization hierarchy.
-- Complex logic: builds a hierarchy from raw categories → domains → operational groups
-- and attaches SLA thresholds and expected recovery patterns.

{{
    config(
        materialized='table'
    )
}}

with categories as (
    -- Distinct delay categories with their domain classification from staging
    select distinct
        delay_category,
        delay_domain
    from {{ ref('stg_delay_incidents') }}
    where _is_invalid_record = false
),

-- Enrich with operational metadata: SLA thresholds, controllability, escalation paths
enriched as (
    select
        delay_category,
        delay_domain,

        -- Whether the delay cause is within Flibco's operational control
        case
            when delay_domain = 'internal_ops' then 'fully_controllable'
            when delay_domain = 'fleet' then 'partially_controllable'
            when delay_domain = 'passenger_ops' then 'partially_controllable'
            when delay_domain = 'infrastructure' then 'uncontrollable'
            when delay_domain = 'environmental' then 'uncontrollable'
            else 'unknown'
        end as controllability,

        -- SLA target: maximum acceptable delay before escalation (minutes)
        case
            when delay_category = 'passenger_boarding' then 10
            when delay_category = 'operational_handover' then 15
            when delay_category = 'security_check' then 20
            when delay_category = 'traffic_congestion' then 20
            when delay_category = 'road_closure' then 30
            when delay_category = 'weather_conditions' then 45
            when delay_category = 'mechanical_issue' then 60
            else 30
        end as sla_threshold_minutes,

        -- Expected frequency tier (for benchmarking)
        case
            when delay_category in ('traffic_congestion', 'passenger_boarding') then 'high_frequency'
            when delay_category in ('operational_handover', 'weather_conditions') then 'medium_frequency'
            else 'low_frequency'
        end as expected_frequency_tier,

        -- Mitigation strategy type
        case
            when delay_category in ('traffic_congestion', 'road_closure') then 'route_optimization'
            when delay_category = 'weather_conditions' then 'proactive_scheduling'
            when delay_category = 'mechanical_issue' then 'preventive_maintenance'
            when delay_category = 'passenger_boarding' then 'process_improvement'
            when delay_category = 'operational_handover' then 'staff_training'
            when delay_category = 'security_check' then 'pre_clearance'
            else 'general_improvement'
        end as mitigation_strategy,

        -- Cascading risk: likelihood that this delay type causes downstream delays
        case
            when delay_category = 'mechanical_issue' then 0.85
            when delay_category = 'road_closure' then 0.70
            when delay_category = 'traffic_congestion' then 0.50
            when delay_category = 'weather_conditions' then 0.60
            when delay_category = 'operational_handover' then 0.40
            when delay_category = 'passenger_boarding' then 0.20
            when delay_category = 'security_check' then 0.15
            else 0.30
        end as cascade_risk_factor

    from categories
)

select
    -- Surrogate key using hash for dimensional modeling
    md5(delay_category) as delay_category_key,
    delay_category,
    delay_domain,
    controllability,
    sla_threshold_minutes,
    expected_frequency_tier,
    mitigation_strategy,
    cascade_risk_factor
from enriched
