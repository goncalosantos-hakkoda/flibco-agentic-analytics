"""
Flibco Operations Executive Dashboard
======================================
Layout: KPI cards + trend charts + route performance table
Data access: Snowflake Semantic View queries (SELECT FROM SEMANTIC_VIEW)

This demonstrates that BI dashboards can use governed semantic view definitions
directly, ensuring metric consistency without reimplementing business logic.
"""

import os

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import snowflake.connector
import streamlit as st

# --- Connection ---


@st.cache_resource
def get_connection():
    return snowflake.connector.connect(
        account=os.environ.get("SNOWFLAKE_ACCOUNT"),
        user=os.environ.get("SNOWFLAKE_USER"),
        authenticator=os.environ.get("SNOWFLAKE_AUTHENTICATOR", "externalbrowser"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH"),
        database=os.environ.get("SNOWFLAKE_DATABASE", "FLIBCO_ANALYTICS"),
        schema="SEMANTIC",
    )


def run_query(sql: str) -> pd.DataFrame:
    conn = get_connection()
    return pd.read_sql(sql, conn)


# --- Page Config ---
st.set_page_config(
    page_title="Flibco Operations - Executive View",
    page_icon="🚌",
    layout="wide",
)

st.title("Flibco Operations Dashboard")
st.caption("Executive Summary | Data via Semantic View")

# --- Sidebar Filters ---
st.sidebar.header("Filters")

routes_df = run_query("""
    SELECT * FROM SEMANTIC_VIEW(
        FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_OPERATIONS_SV
        DIMENSIONS routes.route_name
    )
""")
all_routes = sorted(routes_df["ROUTE_NAME"].unique())
selected_routes = st.sidebar.multiselect("Routes", all_routes, default=all_routes)

quarters_df = run_query("""
    SELECT * FROM SEMANTIC_VIEW(
        FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_OPERATIONS_SV
        DIMENSIONS dates.year_quarter
    )
""")
all_quarters = sorted(quarters_df["YEAR_QUARTER"].unique())
selected_quarters = st.sidebar.multiselect("Quarters", all_quarters, default=all_quarters)

# --- Build filter clause ---
route_filter = ", ".join(f"'{r}'" for r in selected_routes)
quarter_filter = ", ".join(f"'{q}'" for q in selected_quarters)

# --- KPI Cards (Top Row) ---
kpi_df = run_query(f"""
    SELECT * FROM SEMANTIC_VIEW(
        FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_OPERATIONS_SV
        METRICS
            revenue.total_revenue,
            trips.average_occupancy_rate,
            trips.trip_count,
            revenue.revenue_per_passenger
    )
""")

col1, col2, col3, col4 = st.columns(4)

total_revenue = kpi_df["TOTAL_REVENUE"].iloc[0] if len(kpi_df) > 0 else 0
avg_occupancy = kpi_df["AVERAGE_OCCUPANCY_RATE"].iloc[0] if len(kpi_df) > 0 else 0
trip_count = kpi_df["TRIP_COUNT"].iloc[0] if len(kpi_df) > 0 else 0
rev_per_pax = kpi_df["REVENUE_PER_PASSENGER"].iloc[0] if len(kpi_df) > 0 else 0

col1.metric("Total Revenue", f"EUR {total_revenue:,.0f}", help="Sum of all booking fares (EUR) across selected routes and periods.")
col2.metric("Avg Occupancy", f"{avg_occupancy * 100:.1f}%", help="Average ratio of passengers to vehicle capacity (0-100%). Higher = fuller vehicles.")
col3.metric("Trip Count", f"{trip_count:,}", help="Total number of completed trips in the selected period.")
col4.metric("Revenue / Passenger", f"EUR {rev_per_pax:.2f}", help="Total revenue divided by total passengers. Indicates pricing effectiveness.")

st.divider()

# --- Revenue Trend by Quarter (Line Chart) ---
col_left, col_right = st.columns(2)

with col_left:
    st.subheader("Revenue by Quarter")
    st.caption("Total booking revenue (EUR) aggregated by calendar quarter. Shows seasonal demand patterns.")
    revenue_trend = run_query(f"""
        SELECT * FROM SEMANTIC_VIEW(
            FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_OPERATIONS_SV
            DIMENSIONS dates.year_quarter
            METRICS revenue.total_revenue
        )
        WHERE year_quarter IN ({quarter_filter})
        ORDER BY year_quarter
    """)
    if not revenue_trend.empty:
        fig = px.line(
            revenue_trend,
            x="YEAR_QUARTER",
            y="TOTAL_REVENUE",
            markers=True,
            labels={"YEAR_QUARTER": "Quarter", "TOTAL_REVENUE": "Revenue (EUR)"},
        )
        fig.update_layout(showlegend=False, height=350)
        st.plotly_chart(fig, use_container_width=True)

with col_right:
    st.subheader("Occupancy by Route")
    st.caption("Average vehicle fill rate per route. Routes closer to 100% are running near capacity.")
    occupancy_by_route = run_query(f"""
        SELECT * FROM SEMANTIC_VIEW(
            FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_OPERATIONS_SV
            DIMENSIONS routes.route_name
            METRICS trips.average_occupancy_rate
        )
        WHERE route_name IN ({route_filter})
        ORDER BY average_occupancy_rate DESC
    """)
    if not occupancy_by_route.empty:
        fig = px.bar(
            occupancy_by_route,
            x="AVERAGE_OCCUPANCY_RATE",
            y="ROUTE_NAME",
            orientation="h",
            labels={
                "AVERAGE_OCCUPANCY_RATE": "Occupancy Rate",
                "ROUTE_NAME": "",
            },
            color="AVERAGE_OCCUPANCY_RATE",
            color_continuous_scale="Blues",
        )
        fig.update_layout(showlegend=False, height=350, coloraxis_showscale=False)
        st.plotly_chart(fig, use_container_width=True)

st.divider()

# --- Route Performance Table ---
st.subheader("Route Performance Summary")
st.caption("Consolidated view of all routes with key financial and operational metrics. Sortable by any column.")

route_table = run_query(f"""
    SELECT * FROM SEMANTIC_VIEW(
        FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_OPERATIONS_SV
        DIMENSIONS routes.route_name
        METRICS
            revenue.total_revenue,
            trips.average_occupancy_rate,
            trips.trip_count,
            revenue.revenue_per_passenger,
            revenue.booking_count
    )
    WHERE route_name IN ({route_filter})
    ORDER BY total_revenue DESC
""")

if not route_table.empty:
    display_df = route_table.rename(columns={
        "ROUTE_NAME": "Route",
        "TOTAL_REVENUE": "Revenue (EUR)",
        "AVERAGE_OCCUPANCY_RATE": "Occupancy",
        "TRIP_COUNT": "Trips",
        "REVENUE_PER_PASSENGER": "Rev/Pax (EUR)",
        "BOOKING_COUNT": "Bookings",
    })
    display_df["Occupancy"] = (display_df["Occupancy"] * 100).round(1).astype(str) + "%"
    display_df["Revenue (EUR)"] = display_df["Revenue (EUR)"].apply(lambda x: f"{x:,.0f}")
    display_df["Rev/Pax (EUR)"] = display_df["Rev/Pax (EUR)"].apply(lambda x: f"{x:.2f}")
    st.dataframe(display_df, use_container_width=True, hide_index=True)

# --- Footer ---
st.divider()
st.caption(
    "Data sourced from FLIBCO_OPERATIONS_SV semantic view. "
    "Metrics are governed centrally — no local recalculation."
)
