# Flibco Streamlit Dashboards

Two dashboards demonstrating **layout flexibility with KPI consistency** — same governed metrics, different presentations.

## Dashboards

| Dashboard | File | Layout Style | Data Access |
|-----------|------|-------------|-------------|
| Operations Executive | `operations_dashboard.py` | KPI cards + trend charts | Semantic View queries (`SELECT FROM SEMANTIC_VIEW(...)`) |
| Punctuality Analyst | `punctuality_dashboard.py` | Tabbed drill-down + heatmaps | Direct mart table queries |

## Setup

```bash
# Install dependencies
pip install -r streamlit/requirements.txt

# Set connection env vars
export SNOWFLAKE_ACCOUNT=<your-account>
export SNOWFLAKE_USER=<your-user>
export SNOWFLAKE_AUTHENTICATOR=externalbrowser
export SNOWFLAKE_WAREHOUSE=COMPUTE_WH
export SNOWFLAKE_DATABASE=FLIBCO_ANALYTICS
```

## Run

```bash
# Executive dashboard (operations + semantic view)
streamlit run streamlit/operations_dashboard.py

# Analyst dashboard (punctuality + mart tables)
streamlit run streamlit/punctuality_dashboard.py
```

## KPI Consistency Guarantee

Both dashboards derive metrics from the same governed source:
- The semantic views (`FLIBCO_OPERATIONS_SV`, `FLIBCO_PUNCTUALITY_SV`) define metric formulas
- The mart tables (`FCT_TRIPS`, `FCT_PUNCTUALITY`, etc.) are the physical layer the SVs point to
- Whether you query the SV or the mart directly, numbers match because the business logic lives in the dbt transformation layer

This proves BI teams can vary layouts freely without metric drift.
