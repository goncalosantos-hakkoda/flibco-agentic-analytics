# Running dbt in Snowflake

This guide explains how to set up and run dbt (data build tool) against Snowflake, covering installation, authentication, project configuration, and execution.

---

## 1. Install dbt-snowflake

dbt-snowflake is the Snowflake adapter for dbt Core. Install it in an isolated Python environment:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install dbt-snowflake
```

Verify:

```bash
dbt --version
# Should show dbt-core and snowflake adapter versions
```

## 2. Authentication Options

dbt connects to Snowflake using credentials defined in `profiles.yml`. There are several authentication methods:

### Option A: Username/Password

```yaml
# profiles.yml
my_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: DATA_ENGINEER
      warehouse: COMPUTE_WH
      database: MY_DATABASE
      schema: PUBLIC
      threads: 4
```

### Option B: External Browser (SSO/OAuth)

For accounts with SSO configured. Opens a browser window during `dbt run`:

```yaml
my_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      authenticator: externalbrowser
      role: DATA_ENGINEER
      warehouse: COMPUTE_WH
      database: MY_DATABASE
      schema: PUBLIC
      threads: 4
```

### Option C: Key Pair Authentication

Best for CI/CD and automated pipelines:

```bash
# Generate a key pair
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

Assign the public key to your Snowflake user:

```sql
ALTER USER my_user SET RSA_PUBLIC_KEY='MIIBIjANBg...';
```

Then in `profiles.yml`:

```yaml
my_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      private_key_path: "/path/to/rsa_key.p8"
      role: DATA_ENGINEER
      warehouse: COMPUTE_WH
      database: MY_DATABASE
      schema: PUBLIC
      threads: 4
```

### Option D: OAuth Authorization Code

For interactive sessions with token caching:

```yaml
my_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      authenticator: OAUTH_AUTHORIZATION_CODE
      role: DATA_ENGINEER
      warehouse: COMPUTE_WH
      database: MY_DATABASE
      schema: PUBLIC
      threads: 4
```

## 3. Snowflake Account Identifier

The `account` parameter uses Snowflake's account identifier format:

| Format | Example | When to use |
|--------|---------|-------------|
| `<orgname>-<account_name>` | `myorg-myaccount` | Preferred (organization accounts) |
| `<account_locator>` | `xy12345` | Legacy format |
| `<account_locator>.<region>` | `xy12345.us-east-1` | Legacy with non-default region |

Find yours in Snowsight under **Admin > Accounts**, or run:

```sql
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME();
```

## 4. Project Structure

A dbt project for Snowflake follows this layout:

```
my_project/
├── dbt_project.yml        # Project name, paths, materializations
├── profiles.yml           # Connection credentials (keep out of git)
├── packages.yml           # External packages (dbt_utils, etc.)
├── seeds/                 # CSV files loaded as tables
├── models/                # SQL transformations
│   ├── staging/           # 1:1 source cleaning
│   ├── intermediate/      # Business logic
│   └── marts/             # Final consumption layer
├── macros/                # Reusable SQL/Jinja functions
├── tests/                 # Custom data tests
└── analyses/              # Ad-hoc queries (compiled but not run)
```

### dbt_project.yml

Controls materializations and schema routing:

```yaml
name: my_project
version: '1.0.0'
config-version: 2
profile: my_project

model-paths: ["models"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
analysis-paths: ["analyses"]

models:
  my_project:
    staging:
      +materialized: view
      +schema: STAGING
    intermediate:
      +materialized: view
      +schema: INTERMEDIATE
    marts:
      +materialized: table
      +schema: MARTS
```

## 5. Snowflake-Specific Materializations

| Materialization | Snowflake Object | Use Case |
|----------------|-----------------|----------|
| `view` | VIEW | Staging layers, lightweight transforms |
| `table` | TABLE | Mart/gold layer, frequently queried |
| `incremental` | TABLE (with merge) | Large fact tables, append-only data |
| `ephemeral` | CTE (no object) | Reusable subqueries, no persistence |
| `dynamic_table` | DYNAMIC TABLE | Declarative incremental refresh |
| `semantic_view` | SEMANTIC VIEW | AI/analyst semantic layer (via dbt_semantic_view package) |

### Incremental Models

For large tables that grow over time:

```sql
{{ config(
    materialized='incremental',
    unique_key='event_id',
    incremental_strategy='merge'
) }}

SELECT *
FROM {{ ref('stg_events') }}
{% if is_incremental() %}
WHERE event_timestamp > (SELECT MAX(event_timestamp) FROM {{ this }})
{% endif %}
```

### Dynamic Tables

Snowflake-native incremental refresh (no merge logic needed):

```sql
{{ config(
    materialized='dynamic_table',
    target_lag='1 hour',
    snowflake_warehouse='COMPUTE_WH'
) }}

SELECT *
FROM {{ ref('stg_events') }}
```

## 6. Schema Management

By default, dbt concatenates `target.schema` + `custom_schema_name`. To use clean schema names (e.g., just `STAGING` instead of `PUBLIC_STAGING`), override the macro:

```sql
-- macros/generate_schema_name.sql
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
```

## 7. Snowflake Privileges

The dbt role needs these grants:

```sql
-- Database level
GRANT USAGE ON DATABASE my_database TO ROLE dbt_role;
GRANT CREATE SCHEMA ON DATABASE my_database TO ROLE dbt_role;

-- Schema level (for each schema)
GRANT USAGE ON SCHEMA my_database.staging TO ROLE dbt_role;
GRANT CREATE TABLE ON SCHEMA my_database.staging TO ROLE dbt_role;
GRANT CREATE VIEW ON SCHEMA my_database.staging TO ROLE dbt_role;

-- For semantic views
GRANT CREATE SEMANTIC VIEW ON SCHEMA my_database.semantic TO ROLE dbt_role;

-- Warehouse
GRANT USAGE ON WAREHOUSE compute_wh TO ROLE dbt_role;
```

## 8. Running dbt Commands

### Core workflow

```bash
# Install package dependencies
dbt deps

# Load CSV seed files into Snowflake tables
dbt seed

# Run all models (creates views/tables)
dbt run

# Run tests (uniqueness, not_null, relationships)
dbt test

# Seed + run + test in one command
dbt build
```

### Selective execution

```bash
# Run a specific model
dbt run --select my_model

# Run a model and all its upstream dependencies
dbt run --select +my_model

# Run everything downstream of a model
dbt run --select my_model+

# Run a folder
dbt run --select staging

# Run models with a specific tag
dbt run --select tag:daily
```

### Debugging

```bash
# Validate connection
dbt debug

# Compile SQL without executing (inspect in target/compiled/)
dbt compile

# Show the compiled SQL for a model
dbt show --select my_model --limit 10
```

## 9. Environment Variables and CI/CD

Never commit credentials. Use environment variables in `profiles.yml`:

```yaml
account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
user: "{{ env_var('SNOWFLAKE_USER') }}"
password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
```

For CI/CD pipelines (GitHub Actions, GitLab CI, etc.), set these as secrets and use key-pair auth for non-interactive environments.

### Example GitHub Actions step

```yaml
- name: Run dbt
  env:
    SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
    SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
    SNOWFLAKE_PRIVATE_KEY: ${{ secrets.SNOWFLAKE_PRIVATE_KEY }}
  run: |
    dbt deps
    dbt build
```

## 10. Packages

Add external packages in `packages.yml`:

```yaml
packages:
  - package: dbt-labs/dbt_utils
    version: ">=1.1.0"
  - package: Snowflake-Labs/dbt_semantic_view
    version: "1.0.3"
```

Install with `dbt deps`. Common packages for Snowflake:

| Package | Purpose |
|---------|---------|
| `dbt-labs/dbt_utils` | date_spine, surrogate keys, pivot, unpivot |
| `Snowflake-Labs/dbt_semantic_view` | Manage native Semantic Views as dbt models |
| `calogica/dbt_expectations` | Great Expectations-style data tests |
| `dbt-labs/dbt_external_tables` | Manage external tables/stages |

## 11. Seeds vs. Sources vs. External Tables

| Method | Best For | Size Limit |
|--------|----------|-----------|
| Seeds (`dbt seed`) | Small reference data, lookup tables, mock data | < 1M rows |
| Sources (`source()`) | Tables loaded by other tools (Fivetran, Airbyte, custom ETL) | Unlimited |
| External tables | Data in S3/GCS/Azure Blob without copying into Snowflake | Unlimited |

For production workloads, seeds are typically used only for small dimension tables or test fixtures. Operational data should flow through proper ingestion pipelines.

## 12. Semantic Views with dbt

The `Snowflake-Labs/dbt_semantic_view` package adds a `semantic_view` materialization:

```sql
{{ config(materialized='semantic_view') }}

TABLES(
    orders AS {{ ref('fct_orders') }}
        PRIMARY KEY (order_id)
        WITH SYNONYMS ('sales orders', 'purchases')
        COMMENT = 'Order fact table'
)

RELATIONSHIPS(
    orders_to_customers AS
        orders (customer_id) REFERENCES customers
)

FACTS(
    orders.order_total AS order_total
        COMMENT = 'Total order value in USD'
)

DIMENSIONS(
    orders.order_status AS order_status
        WITH SYNONYMS ('status')
        COMMENT = 'Current order status'
)

METRICS(
    orders.total_revenue AS SUM(orders.order_total)
        COMMENT = 'Sum of all order totals'
)
```

The semantic view depends on the gold mart tables, so those must be built first:

```bash
dbt build --select staging intermediate marts
dbt run --select my_semantic_view
```

## 13. Common Pitfalls

| Issue | Solution |
|-------|----------|
| `Object does not exist` on views | Ensure upstream models ran first. Use `dbt build` for dependency ordering. |
| Schema names like `PUBLIC_STAGING` | Override `generate_schema_name` macro (see section 6). |
| Slow seeds for large CSVs | Use `dbt seed --full-refresh` or switch to proper ingestion. |
| Warehouse suspended errors | Set `auto_resume = true` on the warehouse, or use `warehouse_size` in profiles. |
| Role doesn't have privileges | Grant `CREATE TABLE`/`CREATE VIEW` on target schemas. |
| Semantic view "invalid identifier" | The `AS` clause in FACTS/DIMENSIONS is the SQL expression. Ensure column names match the physical table. |

## 14. Useful Snowflake SQL for dbt Development

```sql
-- See what dbt created
SHOW TABLES IN SCHEMA my_database.marts;
SHOW VIEWS IN SCHEMA my_database.staging;
SHOW SEMANTIC VIEWS IN SCHEMA my_database.semantic;

-- Check row counts
SELECT COUNT(*) FROM my_database.marts.fct_orders;

-- Inspect a semantic view
DESCRIBE SEMANTIC VIEW my_database.semantic.my_sv;

-- Query history (see what dbt ran)
SELECT query_text, execution_status, total_elapsed_time
FROM TABLE(information_schema.query_history())
WHERE user_name = 'MY_DBT_USER'
ORDER BY start_time DESC
LIMIT 20;
```
