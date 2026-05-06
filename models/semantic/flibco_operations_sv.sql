{{ config(materialized='semantic_view') }}

TABLES(
    trips AS {{ ref('fct_trips') }}
        PRIMARY KEY (trip_id)
        WITH SYNONYMS ('trips', 'journeys', 'shuttle trips', 'services')
        COMMENT = 'Trip fact table containing one row per completed trip with occupancy metrics',

    revenue AS {{ ref('fct_revenue') }}
        PRIMARY KEY (booking_id)
        WITH SYNONYMS ('bookings', 'revenue', 'sales', 'income', 'turnover')
        COMMENT = 'Revenue fact table containing one row per booking with fare details',

    routes AS {{ ref('dim_routes') }}
        PRIMARY KEY (route_id)
        WITH SYNONYMS ('routes', 'lines', 'shuttle routes', 'connections')
        COMMENT = 'Route dimension with origin/destination, distance, and fare information',

    dates AS {{ ref('dim_date') }}
        PRIMARY KEY (date_key)
        WITH SYNONYMS ('dates', 'calendar', 'time')
        COMMENT = 'Date dimension with calendar attributes including quarter, season, and weekday flags',

    vehicles AS {{ ref('dim_vehicles') }}
        PRIMARY KEY (vehicle_id)
        WITH SYNONYMS ('vehicles', 'buses', 'shuttles', 'minivans', 'fleet')
        COMMENT = 'Vehicle dimension with fleet details including type and capacity'
)

RELATIONSHIPS(
    trips_to_routes AS
        trips (route_id) REFERENCES routes,
    trips_to_dates AS
        trips (date_key) REFERENCES dates,
    trips_to_vehicles AS
        trips (vehicle_id) REFERENCES vehicles,
    revenue_to_routes AS
        revenue (route_id) REFERENCES routes,
    revenue_to_dates AS
        revenue (date_key) REFERENCES dates
)

FACTS(
    trips.passengers_onboard AS passengers_onboard
        WITH SYNONYMS ('riders', 'customers', 'travelers', 'pax')
        COMMENT = 'Number of passengers on a trip',
    trips.vehicle_capacity AS vehicle_capacity
        WITH SYNONYMS ('capacity', 'seats', 'max passengers')
        COMMENT = 'Maximum passenger capacity of the vehicle used for a trip',
    trips.occupancy_rate AS occupancy_rate
        WITH SYNONYMS ('load factor', 'utilization', 'fill rate', 'occupancy')
        COMMENT = 'Ratio of passengers to vehicle capacity (0.0 to 1.0). Also known as load factor or utilization.',
    revenue.passengers AS passengers
        WITH SYNONYMS ('booked passengers', 'pax booked')
        COMMENT = 'Number of passengers in a booking',
    revenue.fare_per_passenger AS fare_per_passenger
        COMMENT = 'Fare charged per passenger in EUR',
    revenue.total_fare AS total_fare
        WITH SYNONYMS ('revenue amount', 'fare', 'booking value', 'sales amount')
        COMMENT = 'Total booking fare amount in EUR'
)

DIMENSIONS(
    routes.route_name AS route_name
        WITH SYNONYMS ('route', 'line', 'shuttle route', 'journey name')
        COMMENT = 'Human-readable route name (e.g., London - Stansted)',
    routes.origin AS origin
        WITH SYNONYMS ('from', 'departure city', 'start')
        COMMENT = 'Departure city for the route',
    routes.destination AS destination
        WITH SYNONYMS ('to', 'arrival', 'airport', 'end')
        COMMENT = 'Arrival location, typically an airport',
    routes.route_vehicle_type AS vehicle_type
        WITH SYNONYMS ('bus type', 'transport type')
        COMMENT = 'Default vehicle type for the route: shuttle_bus or minivan',
    routes.distance_km AS distance_km
        COMMENT = 'Route distance in kilometers',
    dates.full_date AS full_date
        WITH SYNONYMS ('date')
        COMMENT = 'Full calendar date',
    dates.month AS month
        COMMENT = 'Calendar month number (1-12)',
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
        COMMENT = 'Abbreviated day of week name (Mon, Tue, ...)',
    vehicles.veh_type AS vehicle_type
        WITH SYNONYMS ('bus', 'shuttle', 'minivan', 'vehicle category')
        COMMENT = 'Vehicle category: shuttle_bus or minivan',
    vehicles.max_capacity AS capacity
        COMMENT = 'Maximum seating capacity of the vehicle',
    revenue.booking_status AS booking_status
        WITH SYNONYMS ('status', 'booking state')
        COMMENT = 'Booking lifecycle status: completed, cancelled, no_show, or refunded',
    revenue.payment_method AS payment_method
        COMMENT = 'Payment method: credit_card, debit_card, paypal, ideal, bancontact',
    revenue.channel AS channel
        WITH SYNONYMS ('source', 'booking source', 'platform')
        COMMENT = 'Booking channel: website, mobile_app, or partner_api',
    trips.trip_status AS trip_status
        COMMENT = 'Trip status: completed or cancelled'
)

METRICS(
    revenue.total_revenue AS SUM(revenue.total_fare)
        WITH SYNONYMS ('sales', 'income', 'turnover', 'total sales')
        COMMENT = 'Total revenue from all bookings in EUR',
    revenue.completed_revenue AS SUM(
        CASE WHEN revenue.booking_status = 'completed'
             THEN revenue.total_fare ELSE 0 END
    )
        COMMENT = 'Revenue from completed bookings only (excludes refunded/cancelled)',
    trips.total_passengers AS SUM(trips.passengers_onboard)
        WITH SYNONYMS ('riders', 'total riders', 'pax')
        COMMENT = 'Total passengers transported across all trips',
    trips.average_occupancy_rate AS AVG(trips.occupancy_rate)
        WITH SYNONYMS ('avg occupancy', 'average load factor', 'mean utilization', 'average fill rate')
        COMMENT = 'Average occupancy rate across trips (0.0 to 1.0). Multiply by 100 for percentage.',
    trips.trip_count AS COUNT(trips.trip_id)
        WITH SYNONYMS ('number of trips', 'trips count', 'services count')
        COMMENT = 'Total number of trips',
    revenue.booking_count AS COUNT(revenue.booking_id)
        WITH SYNONYMS ('number of bookings', 'bookings count', 'reservations')
        COMMENT = 'Total number of bookings',
    revenue.revenue_per_passenger AS
        SUM(revenue.total_fare) / NULLIF(SUM(revenue.passengers), 0)
        WITH SYNONYMS ('yield', 'revenue per pax', 'avg fare')
        COMMENT = 'Average revenue per passenger in EUR'
)

COMMENT = 'Flibco Operations Semantic View - Shuttle bus and taxi transportation analytics covering routes, trips, bookings, and revenue across European airport connections. Use this to answer questions about occupancy, revenue, route performance, and seasonal trends.'
