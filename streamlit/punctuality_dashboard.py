"""
Flibco Punctuality Analyst Dashboard
=====================================
Layout: Tabbed drill-down with heatmaps, gauges, and detail tables
Data access: Direct mart table queries (FCT_PUNCTUALITY, DIM_*)

This demonstrates the same KPIs presented in an analyst-friendly drill-down
format, querying the underlying mart tables directly while maintaining
metric consistency with the semantic view definitions.
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
        schema="MARTS",
    )


def run_query(sql: str) -> pd.DataFrame:
    conn = get_connection()
    return pd.read_sql(sql, conn)


# --- Page Config ---
st.set_page_config(
    page_title="Flibco Punctuality - Analyst View",
    page_icon="⏱️",
    layout="wide",
)

st.title("Flibco Punctuality Dashboard")
st.caption("Analyst Drill-Down | Data via Mart Tables")

# --- Load dimension data for filters ---
routes_df = run_query("SELECT route_id, route_name FROM FLIBCO_ANALYTICS.MARTS.DIM_ROUTES ORDER BY route_name")
all_routes = routes_df["ROUTE_NAME"].tolist()

# --- Sidebar Filters ---
st.sidebar.header("Filters")
selected_routes = st.sidebar.multiselect("Routes", all_routes, default=all_routes)
route_ids = routes_df[routes_df["ROUTE_NAME"].isin(selected_routes)]["ROUTE_ID"].tolist()
route_filter = ", ".join(f"'{r}'" for r in route_ids)

severity_options = ["on_time", "minor_delay", "moderate_delay", "major_delay", "severe_delay"]
selected_severities = st.sidebar.multiselect("Severity", severity_options, default=severity_options)
severity_filter = ", ".join(f"'{s}'" for s in selected_severities)

# --- Tabs ---
tab1, tab2, tab3 = st.tabs(["Overview", "Route Drill-Down", "Revenue at Risk"])

# ============================================================
# TAB 1: Overview
# ============================================================
with tab1:
    # KPI row
    overview_kpis = run_query(f"""
        SELECT
            COUNT(*) AS total_trips,
            AVG(CASE WHEN is_on_time THEN 1.0 ELSE 0.0 END) AS otp_rate,
            AVG(departure_delay_minutes) AS avg_delay,
            SUM(estimated_delay_cost_eur) AS total_delay_cost,
            AVG(CASE WHEN is_sla_breach THEN 1.0 ELSE 0.0 END) AS sla_breach_rate
        FROM FLIBCO_ANALYTICS.MARTS.FCT_PUNCTUALITY
        WHERE route_id IN ({route_filter})
    """)

    col1, col2, col3, col4, col5 = st.columns(5)
    if not overview_kpis.empty:
        row = overview_kpis.iloc[0]
        col1.metric("Total Trips", f"{int(row['TOTAL_TRIPS']):,}")
        col2.metric("On-Time Rate", f"{row['OTP_RATE'] * 100:.1f}%")
        col3.metric("Avg Delay", f"{row['AVG_DELAY']:.1f} min")
        col4.metric("Total Delay Cost", f"EUR {row['TOTAL_DELAY_COST']:,.0f}")
        col5.metric("SLA Breach Rate", f"{row['SLA_BREACH_RATE'] * 100:.1f}%")

    st.divider()

    col_left, col_right = st.columns(2)

    # OTP Gauge
    with col_left:
        st.subheader("On-Time Performance")
        if not overview_kpis.empty:
            otp_val = overview_kpis.iloc[0]["OTP_RATE"] * 100
            fig = go.Figure(go.Indicator(
                mode="gauge+number",
                value=otp_val,
                number={"suffix": "%"},
                gauge={
                    "axis": {"range": [0, 100]},
                    "bar": {"color": "#2E86AB"},
                    "steps": [
                        {"range": [0, 70], "color": "#FFB3B3"},
                        {"range": [70, 85], "color": "#FFE0B2"},
                        {"range": [85, 100], "color": "#C8E6C9"},
                    ],
                    "threshold": {"line": {"color": "red", "width": 3}, "thickness": 0.75, "value": 85},
                },
                title={"text": "Fleet OTP (target: 85%)"},
            ))
            fig.update_layout(height=300)
            st.plotly_chart(fig, use_container_width=True)

    # Severity Distribution (Pie)
    with col_right:
        st.subheader("Delay Severity Distribution")
        severity_dist = run_query(f"""
            SELECT delay_severity, COUNT(*) AS trip_count
            FROM FLIBCO_ANALYTICS.MARTS.FCT_PUNCTUALITY
            WHERE route_id IN ({route_filter})
              AND delay_severity IN ({severity_filter})
            GROUP BY delay_severity
            ORDER BY trip_count DESC
        """)
        if not severity_dist.empty:
            color_map = {
                "on_time": "#4CAF50",
                "minor_delay": "#FFC107",
                "moderate_delay": "#FF9800",
                "major_delay": "#F44336",
                "severe_delay": "#9C27B0",
            }
            fig = px.pie(
                severity_dist,
                names="DELAY_SEVERITY",
                values="TRIP_COUNT",
                color="DELAY_SEVERITY",
                color_discrete_map=color_map,
            )
            fig.update_layout(height=300)
            st.plotly_chart(fig, use_container_width=True)

    # Route x Month Heatmap
    st.subheader("OTP Heatmap (Route x Month)")
    heatmap_data = run_query(f"""
        SELECT
            r.route_name,
            d.month_name,
            d.month,
            AVG(CASE WHEN p.is_on_time THEN 1.0 ELSE 0.0 END) * 100 AS otp_pct
        FROM FLIBCO_ANALYTICS.MARTS.FCT_PUNCTUALITY p
        JOIN FLIBCO_ANALYTICS.MARTS.DIM_ROUTES r ON p.route_id = r.route_id
        JOIN FLIBCO_ANALYTICS.MARTS.DIM_DATE d ON p.date_key = d.date_key
        WHERE p.route_id IN ({route_filter})
        GROUP BY r.route_name, d.month_name, d.month
        ORDER BY r.route_name, d.month
    """)
    if not heatmap_data.empty:
        pivot = heatmap_data.pivot(index="ROUTE_NAME", columns="MONTH_NAME", values="OTP_PCT")
        month_order = heatmap_data.sort_values("MONTH")["MONTH_NAME"].unique()
        pivot = pivot.reindex(columns=month_order)
        fig = px.imshow(
            pivot.values,
            x=pivot.columns.tolist(),
            y=pivot.index.tolist(),
            color_continuous_scale="RdYlGn",
            aspect="auto",
            labels={"color": "OTP %"},
        )
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

# ============================================================
# TAB 2: Route Drill-Down
# ============================================================
with tab2:
    selected_route = st.selectbox("Select Route for Drill-Down", all_routes)
    drill_route_id = routes_df[routes_df["ROUTE_NAME"] == selected_route]["ROUTE_ID"].iloc[0]

    col_left, col_right = st.columns(2)

    with col_left:
        st.subheader("Delay Category Breakdown")
        category_breakdown = run_query(f"""
            SELECT
                dc.delay_category,
                dc.delay_domain,
                dc.controllability,
                COUNT(*) AS incident_trips,
                AVG(p.departure_delay_minutes) AS avg_delay
            FROM FLIBCO_ANALYTICS.MARTS.FCT_PUNCTUALITY p
            JOIN FLIBCO_ANALYTICS.MARTS.DIM_DELAY_CATEGORIES dc
                ON p.delay_category_key = dc.delay_category_key
            WHERE p.route_id = '{drill_route_id}'
              AND p.primary_delay_category IS NOT NULL
            GROUP BY dc.delay_category, dc.delay_domain, dc.controllability
            ORDER BY incident_trips DESC
        """)
        if not category_breakdown.empty:
            fig = px.bar(
                category_breakdown,
                x="INCIDENT_TRIPS",
                y="DELAY_CATEGORY",
                color="CONTROLLABILITY",
                orientation="h",
                color_discrete_map={
                    "fully_controllable": "#4CAF50",
                    "partially_controllable": "#FFC107",
                    "uncontrollable": "#F44336",
                },
                labels={"INCIDENT_TRIPS": "Trips Affected", "DELAY_CATEGORY": ""},
            )
            fig.update_layout(height=350)
            st.plotly_chart(fig, use_container_width=True)

    with col_right:
        st.subheader("Key Metrics")
        route_metrics = run_query(f"""
            SELECT
                AVG(CASE WHEN is_on_time THEN 1.0 ELSE 0.0 END) * 100 AS otp_pct,
                AVG(departure_delay_minutes) AS avg_dep_delay,
                AVG(CASE WHEN is_sla_breach THEN 1.0 ELSE 0.0 END) * 100 AS sla_breach_pct,
                AVG(CASE WHEN has_cascading_incident THEN 1.0 ELSE 0.0 END) * 100 AS cascade_pct,
                SUM(estimated_delay_cost_eur) AS total_cost,
                AVG(delay_risk_score) AS avg_risk_score
            FROM FLIBCO_ANALYTICS.MARTS.FCT_PUNCTUALITY
            WHERE route_id = '{drill_route_id}'
        """)
        if not route_metrics.empty:
            m = route_metrics.iloc[0]
            st.metric("On-Time Rate", f"{m['OTP_PCT']:.1f}%")
            st.metric("Avg Departure Delay", f"{m['AVG_DEP_DELAY']:.1f} min")
            st.metric("SLA Breach Rate", f"{m['SLA_BREACH_PCT']:.1f}%")
            st.metric("Cascade Rate", f"{m['CASCADE_PCT']:.1f}%")
            st.metric("Total Delay Cost", f"EUR {m['TOTAL_COST']:,.0f}")
            st.metric("Avg Risk Score", f"{m['AVG_RISK_SCORE']:.0f}/100")

    # Delay trend over time
    st.subheader("Delay Trend (Monthly)")
    delay_trend = run_query(f"""
        SELECT
            d.year_quarter,
            AVG(p.departure_delay_minutes) AS avg_delay,
            AVG(CASE WHEN p.is_on_time THEN 1.0 ELSE 0.0 END) * 100 AS otp_pct
        FROM FLIBCO_ANALYTICS.MARTS.FCT_PUNCTUALITY p
        JOIN FLIBCO_ANALYTICS.MARTS.DIM_DATE d ON p.date_key = d.date_key
        WHERE p.route_id = '{drill_route_id}'
        GROUP BY d.year_quarter
        ORDER BY d.year_quarter
    """)
    if not delay_trend.empty:
        fig = px.line(
            delay_trend,
            x="YEAR_QUARTER",
            y=["AVG_DELAY", "OTP_PCT"],
            labels={"YEAR_QUARTER": "Quarter", "value": "", "variable": "Metric"},
        )
        fig.update_layout(height=300)
        st.plotly_chart(fig, use_container_width=True)

# ============================================================
# TAB 3: Revenue at Risk
# ============================================================
with tab3:
    st.subheader("Revenue at Risk by Route")

    risk_data = run_query(f"""
        WITH delay_costs AS (
            SELECT
                p.route_id,
                SUM(p.estimated_delay_cost_eur) AS delay_cost,
                AVG(CASE WHEN p.is_on_time THEN 1.0 ELSE 0.0 END) * 100 AS otp_pct,
                COUNT(*) AS trip_count
            FROM FLIBCO_ANALYTICS.MARTS.FCT_PUNCTUALITY p
            WHERE p.route_id IN ({route_filter})
            GROUP BY p.route_id
        ),
        revenue AS (
            SELECT
                route_id,
                SUM(total_fare) AS total_revenue
            FROM FLIBCO_ANALYTICS.MARTS.FCT_REVENUE
            WHERE route_id IN ({route_filter})
              AND booking_status = 'completed'
            GROUP BY route_id
        )
        SELECT
            r.route_name,
            COALESCE(rev.total_revenue, 0) AS revenue,
            COALESCE(dc.delay_cost, 0) AS delay_cost,
            CASE WHEN rev.total_revenue > 0
                 THEN ROUND(dc.delay_cost / rev.total_revenue * 100, 2)
                 ELSE 0 END AS risk_ratio_pct,
            dc.otp_pct,
            dc.trip_count,
            CASE
                WHEN dc.delay_cost / NULLIF(rev.total_revenue, 0) > 0.10 THEN 'CRITICAL'
                WHEN dc.delay_cost / NULLIF(rev.total_revenue, 0) > 0.05 THEN 'HIGH'
                WHEN dc.delay_cost / NULLIF(rev.total_revenue, 0) > 0.02 THEN 'MODERATE'
                ELSE 'LOW'
            END AS risk_level
        FROM FLIBCO_ANALYTICS.MARTS.DIM_ROUTES r
        LEFT JOIN delay_costs dc ON r.route_id = dc.route_id
        LEFT JOIN revenue rev ON r.route_id = rev.route_id
        WHERE r.route_id IN ({route_filter})
        ORDER BY risk_ratio_pct DESC
    """)

    if not risk_data.empty:
        # Summary metrics
        total_delay_cost = risk_data["DELAY_COST"].sum()
        total_revenue = risk_data["REVENUE"].sum()
        high_risk_count = len(risk_data[risk_data["RISK_LEVEL"].isin(["HIGH", "CRITICAL"])])

        col1, col2, col3 = st.columns(3)
        col1.metric("Total Delay Cost", f"EUR {total_delay_cost:,.0f}")
        col2.metric("Portfolio Risk Ratio", f"{total_delay_cost / max(total_revenue, 1) * 100:.2f}%")
        col3.metric("High/Critical Risk Routes", f"{high_risk_count} / {len(risk_data)}")

        st.divider()

        # Risk table with color coding
        color_map = {"CRITICAL": "🔴", "HIGH": "🟠", "MODERATE": "🟡", "LOW": "🟢"}
        display_risk = risk_data.copy()
        display_risk["Status"] = display_risk["RISK_LEVEL"].map(color_map) + " " + display_risk["RISK_LEVEL"]
        display_risk = display_risk.rename(columns={
            "ROUTE_NAME": "Route",
            "REVENUE": "Revenue (EUR)",
            "DELAY_COST": "Delay Cost (EUR)",
            "RISK_RATIO_PCT": "Risk Ratio %",
            "OTP_PCT": "OTP %",
            "TRIP_COUNT": "Trips",
        })
        display_risk["Revenue (EUR)"] = display_risk["Revenue (EUR)"].apply(lambda x: f"{x:,.0f}")
        display_risk["Delay Cost (EUR)"] = display_risk["Delay Cost (EUR)"].apply(lambda x: f"{x:,.0f}")
        display_risk["OTP %"] = display_risk["OTP %"].apply(lambda x: f"{x:.1f}%")

        st.dataframe(
            display_risk[["Route", "Revenue (EUR)", "Delay Cost (EUR)", "Risk Ratio %", "OTP %", "Trips", "Status"]],
            use_container_width=True,
            hide_index=True,
        )

        # Risk ratio bar chart
        st.subheader("Delay-Cost-to-Revenue Ratio by Route")
        fig = px.bar(
            risk_data,
            x="ROUTE_NAME",
            y="RISK_RATIO_PCT",
            color="RISK_LEVEL",
            color_discrete_map={"CRITICAL": "#D32F2F", "HIGH": "#F57C00", "MODERATE": "#FBC02D", "LOW": "#388E3C"},
            labels={"ROUTE_NAME": "Route", "RISK_RATIO_PCT": "Risk Ratio (%)"},
        )
        fig.add_hline(y=5, line_dash="dash", line_color="orange", annotation_text="High Risk Threshold (5%)")
        fig.add_hline(y=10, line_dash="dash", line_color="red", annotation_text="Critical Threshold (10%)")
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)

# --- Footer ---
st.divider()
st.caption(
    "Data sourced from FLIBCO_ANALYTICS.MARTS (FCT_PUNCTUALITY, DIM_ROUTES, DIM_DATE, DIM_DELAY_CATEGORIES). "
    "Metric definitions match FLIBCO_PUNCTUALITY_SV semantic view."
)
