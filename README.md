# Flibco Agentic Analytics

A sample data engineering project simulating **Flibco's shuttle bus and taxi transportation services** between European cities and airports. Built with dbt on Snowflake using the medallion architecture, culminating in a native Snowflake Semantic View for AI-powered analytics.

## Architecture

```
Mock CSV data (seeds)
       │
       ▼
┌─────────────────────┐
│  RAW (Bronze)       │  ← dbt seed: raw_routes, raw_trips, raw_bookings, raw_vehicles
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  STAGING (Bronze+)  │  ← Views: stg_routes, stg_trips, stg_bookings, stg_vehicles
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  INTERMEDIATE       │  ← Views: int_trip_occupancy, int_booking_revenue
│  (Silver)           │
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  MARTS (Gold)       │  ← Tables: fct_trips, fct_revenue, dim_routes, dim_date, dim_vehicles
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  SEMANTIC           │  ← Native Snowflake Semantic View: FLIBCO_OPERATIONS_SV
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│  Snowflake          │  ← Cortex Analyst / Snowflake Intelligence / Streamlit app
│  Intelligence       │     (natural-language analytics)
└─────────────────────┘
```

## Data Overview

| Source | Records | Description |
|--------|---------|-------------|
| `raw_routes` | 10 | Shuttle routes (London-Stansted, Brussels-Charleroi, etc.) |
| `raw_vehicles` | 18 | Fleet: shuttle buses (40-55 seats) and minivans (8-12 seats) |
| `raw_trips` | 4,152 | Scheduled trips, Jan-Jul 2025, with seasonal variation |
| `raw_bookings` | 44,140 | Individual bookings with dynamic pricing and multiple statuses |

## Target Questions

This project is designed to answer questions like:

1. What is the average occupancy rate for routes between London and Stansted Airport during Summer 2025?
2. What was total revenue in Q2 2025 by route?
3. Which routes had the highest growth in revenue and occupancy in Q2 2025?
4. Which vehicle type has the highest average occupancy?
5. Show revenue per passenger by route.
6. Which routes are underperforming with low occupancy but high capacity?
7. Compare Brussels to Charleroi versus London to Stansted revenue in Q2 2025.

## Prerequisites

- Python 3.11+
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- A Snowflake account with a role that has:
  - `CREATE DATABASE` (or an existing `FLIBCO_ANALYTICS` database)
  - `CREATE SCHEMA`
  - `CREATE TABLE` / `CREATE VIEW`
  - `CREATE SEMANTIC VIEW`
  - `USAGE` on a warehouse

## Setup

### 1. Clone the repository

```bash
git clone <repo-url>
cd flibco-agentic-analytics
```

### 2. Install dependencies with uv

```bash
uv sync
```

This creates a `.venv` and installs `dbt-snowflake` and all transitive dependencies from the lockfile.

To install with linting tools (sqlfluff):

```bash
uv sync --extra dev
```

Then install dbt packages:

```bash
uv run dbt deps
```

### 3. Configure environment variables

Set the following environment variables for your Snowflake connection:

```bash
export SNOWFLAKE_ACCOUNT="<your-account-identifier>"
export SNOWFLAKE_USER="<your-username>"
export SNOWFLAKE_PASSWORD="<your-password>"          # or use authenticator
export SNOWFLAKE_AUTHENTICATOR="snowflake"           # or externalbrowser, oauth, etc.
export SNOWFLAKE_ROLE="DATA_ENGINEER"
export SNOWFLAKE_WAREHOUSE="COMPUTE_WH"
export SNOWFLAKE_DATABASE="FLIBCO_ANALYTICS"
export SNOWFLAKE_SCHEMA="PUBLIC"
```

### 4. Create the Snowflake database and schemas

```sql
CREATE DATABASE IF NOT EXISTS FLIBCO_ANALYTICS;
USE DATABASE FLIBCO_ANALYTICS;
CREATE SCHEMA IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS STAGING;
CREATE SCHEMA IF NOT EXISTS INTERMEDIATE;
CREATE SCHEMA IF NOT EXISTS MARTS;
CREATE SCHEMA IF NOT EXISTS SEMANTIC;
```

### 5. Run the pipeline

```bash
# Load seed data into RAW schema
uv run dbt seed

# Build staging, intermediate, and mart models
uv run dbt build --select staging intermediate marts

# Create the semantic view (requires gold marts to exist first)
uv run dbt run --select flibco_operations_sv

# Run tests to validate data integrity
uv run dbt test
```

Or run everything at once:

```bash
uv run dbt build
```

## Project Structure

```
flibco-agentic-analytics/
├── pyproject.toml             # uv project: Python deps (dbt-snowflake)
├── uv.lock                    # Lockfile for reproducible installs
├── .python-version            # Python version pin (3.12)
├── dbt_project.yml            # Project configuration
├── packages.yml               # dbt_utils + dbt_semantic_view
├── profiles.yml               # Connection profile (env-var based)
├── seeds/                     # Source CSV files
│   ├── raw_routes.csv
│   ├── raw_vehicles.csv
│   ├── raw_trips.csv
│   └── raw_bookings.csv
├── models/
│   ├── staging/               # 1:1 cleaned source views
│   │   ├── _staging.yml
│   │   ├── stg_routes.sql
│   │   ├── stg_vehicles.sql
│   │   ├── stg_trips.sql
│   │   └── stg_bookings.sql
│   ├── intermediate/          # Business logic joins
│   │   ├── _intermediate.yml
│   │   ├── int_trip_occupancy.sql
│   │   └── int_booking_revenue.sql
│   ├── marts/                 # Star schema (facts + dimensions)
│   │   ├── _marts.yml
│   │   ├── fct_trips.sql
│   │   ├── fct_revenue.sql
│   │   ├── dim_routes.sql
│   │   ├── dim_date.sql
│   │   └── dim_vehicles.sql
│   └── semantic/              # Native Snowflake Semantic View
│       ├── _semantic.yml
│       └── flibco_operations_sv.sql
├── macros/
│   └── generate_schema_name.sql
├── analyses/
│   └── sample_questions.sql   # Verified demo queries
└── docs/
    └── dbt-in-snowflake.md    # Guide: setting up dbt in Snowflake
```

## Semantic View

The semantic view (`FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_OPERATIONS_SV`) provides:

- **Logical tables:** trips, revenue, routes, dates, vehicles
- **Relationships:** Star-schema joins between facts and dimensions
- **Facts:** passengers_onboard, vehicle_capacity, occupancy_rate, total_fare
- **Dimensions:** route_name, origin, destination, quarter, season, booking_status, channel
- **Metrics:** total_revenue, average_occupancy_rate, trip_count, booking_count, revenue_per_passenger
- **Synonyms:** Natural language mappings (e.g., "sales" → revenue, "load factor" → occupancy)

This semantic view serves as the governed business context for:
- **Snowflake Intelligence** — attach the semantic view to an agent
- **Streamlit + Cortex Analyst API** — pass the semantic view in the API payload
- **Any Cortex-powered app** — natural language to SQL via the semantic layer

## Demo Interfaces (Future)

### Option A: Snowflake Intelligence
Configure a Snowflake Intelligence agent connected to `FLIBCO_OPERATIONS_SV`. Prospects ask questions directly in Snowsight.

### Option B: Streamlit + Cortex Analyst
A controlled demo app with suggested questions, SQL display, table/chart output, and feedback buttons.

## Governance & Feedback Loop (Future)

Analyst feedback can improve the semantic knowledge base:
- Thumbs up/down on answers
- Verified query candidates
- Synonym and metric corrections

Store in: `AGENT_FEEDBACK.QUESTION_FEEDBACK` / `AGENT_FEEDBACK.VERIFIED_QUERY_CANDIDATES`

Feedback goes through a review/approval step before updating the semantic view.
