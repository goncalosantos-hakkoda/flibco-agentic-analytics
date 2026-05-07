{{ config(materialized='semantic_view') }}

TABLES(
    punctuality AS {{ ref('fct_punctuality') }}
        PRIMARY KEY (trip_id)
        WITH SYNONYMS ('punctuality', 'delays', 'on-time performance', 'OTP', 'timeliness')
        COMMENT = 'Punctuality fact table with one row per trip containing delay metrics, severity classifications, and cost-of-delay estimates',

    delay_categories AS {{ ref('dim_delay_categories') }}
        PRIMARY KEY (delay_category_key)
        WITH SYNONYMS ('delay reasons', 'delay types', 'incident types', 'disruption categories')
        COMMENT = 'Delay category dimension with SLA thresholds, controllability, and mitigation strategies',

    routes AS {{ ref('dim_routes') }}
        PRIMARY KEY (route_id)
        WITH SYNONYMS ('routes', 'lines', 'shuttle routes', 'connections')
        COMMENT = 'Route dimension with origin/destination, distance, and fare information (shared with operations view)',

    dates AS {{ ref('dim_date') }}
        PRIMARY KEY (date_key)
        WITH SYNONYMS ('dates', 'calendar', 'time')
        COMMENT = 'Date dimension with calendar attributes (shared with operations view)',

    vehicles AS {{ ref('dim_vehicles') }}
        PRIMARY KEY (vehicle_id)
        WITH SYNONYMS ('vehicles', 'buses', 'shuttles', 'minivans', 'fleet')
        COMMENT = 'Vehicle dimension with fleet details (shared with operations view)'
)

RELATIONSHIPS(
    punctuality_to_routes AS
        punctuality (route_id) REFERENCES routes,
    punctuality_to_dates AS
        punctuality (date_key) REFERENCES dates,
    punctuality_to_vehicles AS
        punctuality (vehicle_id) REFERENCES vehicles,
    punctuality_to_delay_categories AS
        punctuality (delay_category_key) REFERENCES delay_categories
)

FACTS(
    punctuality.departure_delay_minutes AS departure_delay_minutes
        WITH SYNONYMS ('departure delay', 'late departure', 'minutes late departing')
        COMMENT = 'Minutes between scheduled and actual departure. Positive = late, negative = early.',
    punctuality.arrival_delay_minutes AS arrival_delay_minutes
        WITH SYNONYMS ('arrival delay', 'late arrival', 'minutes late arriving')
        COMMENT = 'Minutes between scheduled and actual arrival. Positive = late, negative = early.',
    punctuality.scheduled_duration_minutes AS scheduled_duration_minutes
        COMMENT = 'Planned travel duration in minutes',
    punctuality.actual_duration_minutes AS actual_duration_minutes
        COMMENT = 'Actual travel duration in minutes',
    punctuality.travel_time_ratio AS travel_time_ratio
        WITH SYNONYMS ('efficiency ratio', 'duration ratio')
        COMMENT = 'Ratio of actual to scheduled duration. Values > 1.0 indicate trip took longer than planned.',
    punctuality.incident_count AS incident_count
        WITH SYNONYMS ('number of incidents', 'disruptions count')
        COMMENT = 'Number of delay incidents recorded for this trip',
    punctuality.total_incident_delay_minutes AS total_incident_delay_minutes
        COMMENT = 'Sum of all incident delay minutes for this trip',
    punctuality.total_passenger_delay_minutes AS total_passenger_delay_minutes
        WITH SYNONYMS ('passenger impact', 'disruption impact', 'pax delay minutes')
        COMMENT = 'Total passenger-delay-minutes: passengers_affected * delay_minutes. Key disruption cost metric.',
    punctuality.delay_risk_score AS delay_risk_score
        WITH SYNONYMS ('risk score', 'delay risk')
        COMMENT = 'Compound delay risk score (0-100) combining delay magnitude, recurrence, and vehicle reliability',
    punctuality.vehicle_rolling_avg_delay_5trips AS vehicle_rolling_avg_delay_5trips
        WITH SYNONYMS ('vehicle reliability', 'rolling delay average')
        COMMENT = 'Rolling 5-trip average departure delay for the vehicle (vehicle reliability indicator)',
    punctuality.passengers_onboard AS passengers_onboard
        WITH SYNONYMS ('passengers', 'riders', 'pax')
        COMMENT = 'Number of passengers on this trip (affected by the delay)',
    punctuality.estimated_delay_cost_eur AS estimated_delay_cost_eur
        WITH SYNONYMS ('delay cost', 'cost of delay', 'delay expense')
        COMMENT = 'Estimated financial impact of delay in EUR (0.50 EUR per passenger-delay-minute beyond threshold)',
    delay_categories.sla_threshold_minutes AS sla_threshold_minutes
        COMMENT = 'Maximum acceptable delay before SLA breach for this delay category',
    delay_categories.cascade_risk_factor AS cascade_risk_factor
        WITH SYNONYMS ('cascade risk', 'propagation risk')
        COMMENT = 'Probability (0-1) that this delay category causes downstream cascading delays'
)

DIMENSIONS(
    -- Route dimensions (shared with flibco_operations_sv)
    routes.route_name AS route_name
        WITH SYNONYMS ('route', 'line', 'shuttle route')
        COMMENT = 'Human-readable route name (e.g., London - Stansted)',
    routes.origin AS origin
        WITH SYNONYMS ('from', 'departure city', 'start')
        COMMENT = 'Departure city for the route',
    routes.destination AS destination
        WITH SYNONYMS ('to', 'arrival', 'airport', 'end')
        COMMENT = 'Arrival location, typically an airport',
    routes.distance_km AS distance_km
        COMMENT = 'Route distance in kilometers',

    -- Date dimensions (shared with flibco_operations_sv)
    dates.full_date AS full_date
        WITH SYNONYMS ('date')
        COMMENT = 'Full calendar date',
    dates.month_name AS month_name
        COMMENT = 'Abbreviated month name (Jan, Feb, ...)',
    dates.quarter AS quarter
        WITH SYNONYMS ('Q1', 'Q2', 'Q3', 'Q4', 'quarterly')
        COMMENT = 'Calendar quarter (1-4)',
    dates.year AS year
        COMMENT = 'Calendar year',
    dates.year_quarter AS year_quarter
        COMMENT = 'Year and quarter combined (e.g., 2025-2 for Q2 2025)',
    dates.season AS season
        WITH SYNONYMS ('seasonal', 'time of year')
        COMMENT = 'Season name: Winter, Spring, Summer, or Autumn',
    dates.is_weekday AS is_weekday
        COMMENT = 'Whether the date is a weekday (Monday-Friday)',
    dates.day_name AS day_name
        COMMENT = 'Day of week (Mon, Tue, ...)',

    -- Vehicle dimensions (shared with flibco_operations_sv)
    vehicles.vehicle_type AS vehicle_type
        WITH SYNONYMS ('bus type', 'transport type')
        COMMENT = 'Vehicle category: shuttle_bus or minivan',
    vehicles.capacity AS capacity
        COMMENT = 'Maximum seating capacity of the vehicle',

    -- Punctuality-specific dimensions
    punctuality.service_type AS service_type
        WITH SYNONYMS ('service class', 'trip type')
        COMMENT = 'Schedule service type: regular, express, or peak_hour',
    punctuality.departure_window AS departure_window
        WITH SYNONYMS ('time of day', 'time slot')
        COMMENT = 'Time-of-day window: early_morning, morning, midday, afternoon, evening, night',
    punctuality.is_weekend_service AS is_weekend_service
        COMMENT = 'Whether the trip was scheduled on a weekend',
    punctuality.schedule_density AS schedule_density
        COMMENT = 'Route schedule congestion level: high, medium, or low',
    punctuality.delay_severity AS delay_severity
        WITH SYNONYMS ('severity', 'delay level', 'how late')
        COMMENT = 'Severity tier: on_time, minor_delay, moderate_delay, major_delay, severe_delay',
    punctuality.is_on_time AS is_on_time
        WITH SYNONYMS ('on time', 'punctual', 'OTP flag')
        COMMENT = 'Whether both departure and arrival were within 5-minute threshold',
    punctuality.is_on_time_departure AS is_on_time_departure
        COMMENT = 'Whether departure was within 5-minute threshold',
    punctuality.has_cascading_incident AS has_cascading_incident
        WITH SYNONYMS ('cascade', 'propagated delay')
        COMMENT = 'Whether this trip had a cascading delay from a prior trip on the same vehicle',
    punctuality.is_sla_breach AS is_sla_breach
        WITH SYNONYMS ('SLA violation', 'breach', 'out of SLA')
        COMMENT = 'Whether the delay exceeded the SLA threshold for its category',
    punctuality.primary_delay_category AS primary_delay_category
        WITH SYNONYMS ('delay reason', 'cause', 'root cause')
        COMMENT = 'Primary delay category: traffic_congestion, weather_conditions, mechanical_issue, etc.',
    punctuality.route_delay_percentile_band AS route_delay_percentile_band
        COMMENT = 'How this trip compares to its route average: below_median, p50_to_p75, p75_to_p90, above_p90',

    -- Delay category dimensions
    delay_categories.delay_category AS delay_category
        WITH SYNONYMS ('delay type', 'incident category', 'reason')
        COMMENT = 'Specific delay category from the incident report',
    delay_categories.delay_domain AS delay_domain
        WITH SYNONYMS ('cause domain', 'responsibility area')
        COMMENT = 'Operational domain: infrastructure, environmental, fleet, passenger_ops, internal_ops',
    delay_categories.controllability AS controllability
        COMMENT = 'Whether Flibco can control this delay type: fully_controllable, partially_controllable, uncontrollable',
    delay_categories.mitigation_strategy AS mitigation_strategy
        COMMENT = 'Recommended mitigation approach for this delay category',
    delay_categories.expected_frequency_tier AS expected_frequency_tier
        COMMENT = 'How often this delay type typically occurs: high_frequency, medium_frequency, low_frequency'
)

METRICS(
    punctuality.on_time_rate AS AVG(
        CASE WHEN punctuality.is_on_time = TRUE THEN 1.0 ELSE 0.0 END
    )
        WITH SYNONYMS ('OTP', 'on-time performance', 'punctuality rate', 'on time percentage')
        COMMENT = 'On-time performance rate (0.0 to 1.0). A trip is on-time if both departure and arrival are within 5 minutes of schedule.',

    punctuality.avg_departure_delay AS AVG(punctuality.departure_delay_minutes)
        WITH SYNONYMS ('average delay', 'mean delay', 'avg late minutes')
        COMMENT = 'Average departure delay in minutes across all trips',

    punctuality.avg_arrival_delay AS AVG(punctuality.arrival_delay_minutes)
        COMMENT = 'Average arrival delay in minutes across all trips',

    punctuality.total_delay_cost AS SUM(punctuality.estimated_delay_cost_eur)
        WITH SYNONYMS ('delay cost', 'total delay expense', 'disruption cost')
        COMMENT = 'Total estimated financial impact of delays in EUR',

    punctuality.total_passenger_delay_impact AS SUM(punctuality.total_passenger_delay_minutes)
        WITH SYNONYMS ('total disruption', 'cumulative passenger impact')
        COMMENT = 'Total passenger-delay-minutes across all trips (key service quality KPI)',

    punctuality.sla_breach_rate AS AVG(
        CASE WHEN punctuality.is_sla_breach = TRUE THEN 1.0 ELSE 0.0 END
    )
        WITH SYNONYMS ('SLA violation rate', 'breach rate')
        COMMENT = 'Rate of trips that breached their category SLA threshold (0.0 to 1.0)',

    punctuality.severe_delay_rate AS AVG(
        CASE WHEN punctuality.delay_severity IN ('major_delay', 'severe_delay') THEN 1.0 ELSE 0.0 END
    )
        WITH SYNONYMS ('major delay rate', 'severe disruption rate')
        COMMENT = 'Rate of trips with major or severe delays (>30 minutes)',

    punctuality.cascade_rate AS AVG(
        CASE WHEN punctuality.has_cascading_incident = TRUE THEN 1.0 ELSE 0.0 END
    )
        WITH SYNONYMS ('cascade frequency', 'propagation rate')
        COMMENT = 'Rate of trips affected by cascading delays from prior trips',

    punctuality.avg_delay_risk_score AS AVG(punctuality.delay_risk_score)
        WITH SYNONYMS ('average risk', 'mean risk score')
        COMMENT = 'Average compound delay risk score (0-100) across trips',

    punctuality.delayed_trip_count AS COUNT(
        CASE WHEN punctuality.is_on_time = FALSE THEN punctuality.trip_id END
    )
        WITH SYNONYMS ('late trips', 'delayed count', 'number of delayed trips')
        COMMENT = 'Total number of trips that were not on time'
)

COMMENT = 'Flibco Punctuality Semantic View - On-time performance analytics covering departure/arrival delays, delay root causes, SLA compliance, cascading delay detection, and cost-of-delay estimates. Shares route, vehicle, and date dimensions with the Operations semantic view for cross-domain analysis.'
