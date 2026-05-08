---
name: revenue_at_risk
description: >
  Calculates revenue at risk from poor on-time performance by correlating
  delay costs with booking revenue across routes. Identifies which routes
  have the highest financial exposure from chronic delays. Use when asked
  about "revenue at risk", "cost of delays impact", "delay impact on revenue",
  "which routes are losing money from delays", or "financial exposure from OTP".
---

## Instructions

When the user asks about the financial impact of delays on revenue, perform a cross-domain analysis combining punctuality costs with operations revenue.

### Step 1: Determine Scope

If the user specifies routes or a time period, use them. Otherwise:
- Time period: trailing 3 months (last full quarter)
- Routes: all routes

### Step 2: Query Delay Costs

Using the `FLIBCO_PUNCTUALITY_SV` tool, retrieve by route:
- SUM of estimated_delay_cost_eur
- On-time rate (AVG of is_on_time as percentage)
- Total passenger-delay-minutes
- SLA breach rate
- Count of trips with delay_severity IN ('major_delay', 'severe_delay')

### Step 3: Query Revenue

Using the `flibco_operations_analyst` tool, retrieve by route for the same period:
- SUM of total_fare as total_revenue
- Total trip count
- Total passengers

### Step 4: Calculate Risk Metrics

For each route compute:
- **Delay-cost-to-revenue ratio**: delay_cost / total_revenue (as percentage)
- **Risk level classification**:
  - Ratio > 10% → `CRITICAL`
  - Ratio > 5% → `HIGH`
  - Ratio > 2% → `MODERATE`
  - Ratio <= 2% → `LOW`
- **Annualized delay cost**: (period_delay_cost / months_in_period) * 12
- **Churn risk estimate**: For routes with OTP below 85%, estimate 2% additional revenue at risk for every 1 percentage point below 85% OTP (this models customer switching due to unreliability)

### Step 5: Present Findings

**Revenue at Risk Summary**

| Route | Revenue | Delay Cost | Ratio | Risk Level | OTP | Annualized Exposure |
|-------|---------|------------|-------|------------|-----|---------------------|
| ... sorted by ratio descending |

**Key Findings**:
- Total portfolio delay cost: EUR X
- Number of high/critical risk routes: N out of 10
- Total annualized revenue at risk: EUR X

**Top 3 Routes by Exposure**:
For each, provide:
- The dominant delay category (from punctuality data)
- The recommended mitigation strategy
- Estimated savings if delay cost is reduced by 50%

**Recommended Actions** (prioritized):
1. Immediate: Address critical-risk routes first
2. Short-term: Focus on controllable delay categories (fleet, internal_ops)
3. Monitoring: Track routes approaching the 5% threshold

### Formatting Rules

- All monetary values in EUR, rounded to nearest euro
- Percentages to 1 decimal place
- Sort routes by risk level (critical first), then by delay-cost-to-revenue ratio
- If all routes are LOW risk, acknowledge good performance and highlight any trending concerns
