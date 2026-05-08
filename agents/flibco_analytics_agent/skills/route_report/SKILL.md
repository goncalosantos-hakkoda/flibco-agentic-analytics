---
name: route_report
description: >
  Generates a comprehensive route performance report combining occupancy,
  revenue, and punctuality metrics into an executive summary with actionable
  insights. Use when asked for a "route report", "route performance",
  "how is route X doing", or "give me a full summary of route X".
---

## Instructions

When the user asks about a route's overall performance, generate a structured multi-domain report by querying both semantic views.

### Step 1: Identify the Route

Extract the route from the user's question. Match against `route_name`, `origin`, or `destination`. If ambiguous, ask the user to clarify which route they mean.

### Step 2: Determine Time Period

If the user specifies a time period, use it. Otherwise default to the last full quarter.

### Step 3: Query Operations Data

Using the `flibco_operations_analyst` tool, retrieve for the identified route and period:
- Total revenue (SUM of total_fare)
- Revenue per passenger
- Average occupancy rate
- Total trip count
- Total passengers transported

Also retrieve fleet-wide averages for the same period (all routes) to enable comparison.

### Step 4: Query Punctuality Data

Using the `FLIBCO_PUNCTUALITY_SV` tool, retrieve for the same route and period:
- On-time rate (% of trips where is_on_time = true)
- Average departure delay in minutes
- SLA breach rate
- Delay severity distribution (count by delay_severity)
- Total estimated delay cost in EUR
- Top 2-3 delay categories for this route
- Cascade rate (% of trips with cascading incidents)

### Step 5: Generate the Report

Present findings in this structure:

**Executive Summary**
2-3 sentences summarizing the route's health across operations and punctuality. Highlight if performance is above or below fleet average.

**Operational KPIs**
| Metric | Route Value | Fleet Average | Status |
|--------|-------------|---------------|--------|
| Occupancy Rate | X% | Y% | above/below |
| Trip Count | N | M | - |
| Passengers | N | M | - |

**Financial Performance**
| Metric | Value |
|--------|-------|
| Total Revenue | EUR X |
| Revenue per Passenger | EUR X |
| vs Fleet Avg Revenue/Pax | +/-X% |

**Punctuality Score**
| Metric | Value |
|--------|-------|
| On-Time Rate | X% |
| Avg Departure Delay | X min |
| SLA Breach Rate | X% |
| Estimated Delay Cost | EUR X |

**Delay Breakdown**
Top delay categories with their frequency and average delay minutes.

**Recommendations**
2-3 actionable recommendations based on the data. Examples:
- If OTP < 80%: "Consider schedule buffer adjustments during [peak window]"
- If delay cost > 5% of revenue: "Prioritize [top delay category] mitigation"
- If occupancy is low but OTP is high: "Route is reliable — opportunity to increase marketing"
- If cascade rate is high: "Review vehicle turnaround scheduling"
