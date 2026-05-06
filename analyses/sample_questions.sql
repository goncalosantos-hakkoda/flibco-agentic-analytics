-- =============================================================================
-- Flibco Analytics - Verified Demo Questions
-- These queries run against the gold mart layer and serve as reference
-- implementations for the semantic view / Cortex Analyst.
-- =============================================================================

-- Q1: What is the average occupancy rate for routes between London and Stansted
--     Airport during Summer 2025?
SELECT
    r.route_name,
    d.season,
    ROUND(AVG(t.occupancy_rate) * 100, 1) AS avg_occupancy_pct,
    COUNT(t.trip_id) AS trip_count
FROM {{ ref('fct_trips') }} t
JOIN {{ ref('dim_routes') }} r ON t.route_id = r.route_id
JOIN {{ ref('dim_date') }} d ON t.date_key = d.date_key
WHERE r.route_name = 'London - Stansted'
  AND d.season = 'Summer'
  AND d.year = 2025
GROUP BY r.route_name, d.season;


-- Q2: What was total revenue in Q2 2025 by route?
SELECT
    r.route_name,
    d.year_quarter,
    ROUND(SUM(rev.total_fare), 2) AS total_revenue,
    COUNT(rev.booking_id) AS booking_count
FROM {{ ref('fct_revenue') }} rev
JOIN {{ ref('dim_routes') }} r ON rev.route_id = r.route_id
JOIN {{ ref('dim_date') }} d ON rev.date_key = d.date_key
WHERE d.quarter = 2
  AND d.year = 2025
GROUP BY r.route_name, d.year_quarter
ORDER BY total_revenue DESC;


-- Q3: Which routes had the highest growth in revenue and occupancy in Q2 2025?
WITH quarterly_revenue AS (
    SELECT
        r.route_name,
        d.quarter,
        SUM(rev.total_fare) AS total_revenue
    FROM {{ ref('fct_revenue') }} rev
    JOIN {{ ref('dim_routes') }} r ON rev.route_id = r.route_id
    JOIN {{ ref('dim_date') }} d ON rev.date_key = d.date_key
    WHERE d.year = 2025
      AND d.quarter IN (1, 2)
    GROUP BY r.route_name, d.quarter
),
quarterly_occupancy AS (
    SELECT
        r.route_name,
        d.quarter,
        AVG(t.occupancy_rate) AS avg_occupancy
    FROM {{ ref('fct_trips') }} t
    JOIN {{ ref('dim_routes') }} r ON t.route_id = r.route_id
    JOIN {{ ref('dim_date') }} d ON t.date_key = d.date_key
    WHERE d.year = 2025
      AND d.quarter IN (1, 2)
    GROUP BY r.route_name, d.quarter
),
revenue_growth AS (
    SELECT
        route_name,
        MAX(CASE WHEN quarter = 1 THEN total_revenue END) AS q1_revenue,
        MAX(CASE WHEN quarter = 2 THEN total_revenue END) AS q2_revenue,
        ROUND(
            (MAX(CASE WHEN quarter = 2 THEN total_revenue END) -
             MAX(CASE WHEN quarter = 1 THEN total_revenue END)) /
            NULLIF(MAX(CASE WHEN quarter = 1 THEN total_revenue END), 0) * 100, 1
        ) AS revenue_growth_pct
    FROM quarterly_revenue
    GROUP BY route_name
),
occupancy_growth AS (
    SELECT
        route_name,
        MAX(CASE WHEN quarter = 1 THEN avg_occupancy END) AS q1_occupancy,
        MAX(CASE WHEN quarter = 2 THEN avg_occupancy END) AS q2_occupancy,
        ROUND(
            (MAX(CASE WHEN quarter = 2 THEN avg_occupancy END) -
             MAX(CASE WHEN quarter = 1 THEN avg_occupancy END)) /
            NULLIF(MAX(CASE WHEN quarter = 1 THEN avg_occupancy END), 0) * 100, 1
        ) AS occupancy_growth_pct
    FROM quarterly_occupancy
    GROUP BY route_name
)
SELECT
    rg.route_name,
    ROUND(rg.q1_revenue, 2) AS q1_revenue,
    ROUND(rg.q2_revenue, 2) AS q2_revenue,
    rg.revenue_growth_pct,
    ROUND(og.q1_occupancy * 100, 1) AS q1_occupancy_pct,
    ROUND(og.q2_occupancy * 100, 1) AS q2_occupancy_pct,
    og.occupancy_growth_pct
FROM revenue_growth rg
JOIN occupancy_growth og ON rg.route_name = og.route_name
ORDER BY rg.revenue_growth_pct DESC;


-- Q4: Which vehicle type has the highest average occupancy?
SELECT
    v.vehicle_type,
    ROUND(AVG(t.occupancy_rate) * 100, 1) AS avg_occupancy_pct,
    COUNT(t.trip_id) AS trip_count
FROM {{ ref('fct_trips') }} t
JOIN {{ ref('dim_vehicles') }} v ON t.vehicle_id = v.vehicle_id
GROUP BY v.vehicle_type
ORDER BY avg_occupancy_pct DESC;


-- Q5: Show revenue per passenger by route
SELECT
    r.route_name,
    ROUND(SUM(rev.total_fare) / NULLIF(SUM(rev.passengers), 0), 2) AS revenue_per_passenger,
    SUM(rev.passengers) AS total_passengers,
    ROUND(SUM(rev.total_fare), 2) AS total_revenue
FROM {{ ref('fct_revenue') }} rev
JOIN {{ ref('dim_routes') }} r ON rev.route_id = r.route_id
WHERE rev.booking_status = 'completed'
GROUP BY r.route_name
ORDER BY revenue_per_passenger DESC;


-- Q6: Which routes are underperforming (low occupancy but high capacity)?
SELECT
    r.route_name,
    r.vehicle_type,
    ROUND(AVG(t.occupancy_rate) * 100, 1) AS avg_occupancy_pct,
    ROUND(AVG(t.vehicle_capacity), 0) AS avg_capacity,
    COUNT(t.trip_id) AS trip_count
FROM {{ ref('fct_trips') }} t
JOIN {{ ref('dim_routes') }} r ON t.route_id = r.route_id
GROUP BY r.route_name, r.vehicle_type
HAVING AVG(t.occupancy_rate) < 0.6
ORDER BY avg_occupancy_pct ASC;


-- Q7: Compare Brussels to Charleroi vs London to Stansted revenue in Q2 2025
SELECT
    r.route_name,
    ROUND(SUM(rev.total_fare), 2) AS q2_revenue,
    COUNT(rev.booking_id) AS q2_bookings,
    SUM(rev.passengers) AS q2_passengers
FROM {{ ref('fct_revenue') }} rev
JOIN {{ ref('dim_routes') }} r ON rev.route_id = r.route_id
JOIN {{ ref('dim_date') }} d ON rev.date_key = d.date_key
WHERE r.route_name IN ('Brussels - Charleroi', 'London - Stansted')
  AND d.quarter = 2
  AND d.year = 2025
GROUP BY r.route_name
ORDER BY q2_revenue DESC;


-- Q8: Average occupancy rate by route and month
SELECT
    r.route_name,
    d.month_name,
    d.month,
    ROUND(AVG(t.occupancy_rate) * 100, 1) AS avg_occupancy_pct,
    COUNT(t.trip_id) AS trip_count
FROM {{ ref('fct_trips') }} t
JOIN {{ ref('dim_routes') }} r ON t.route_id = r.route_id
JOIN {{ ref('dim_date') }} d ON t.date_key = d.date_key
WHERE d.year = 2025
GROUP BY r.route_name, d.month_name, d.month
ORDER BY r.route_name, d.month;
