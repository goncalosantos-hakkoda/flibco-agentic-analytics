# When to Create New Semantic Views

This document provides guidance on when a single semantic view is sufficient and when to split into multiple semantic views.

---

## Default: Start With One

A single semantic view is the right choice when:

- All tables belong to the same business domain
- One team or audience consumes the analytics
- The star schema is cohesive (shared dimensions across facts)
- Cortex Analyst needs full context about how tables relate

Cortex Analyst performs better with a single, well-connected semantic view. More context means better SQL generation — the model can reason about joins, metrics, and filters across the full domain.

---

## When to Add a Second Semantic View

Split into multiple semantic views when one of these conditions is true:

### 1. Distinct Business Domains

The data covers unrelated domains that don't share dimensions or logic.

| Domain | Semantic View | Tables |
|--------|--------------|--------|
| Operations | `operations_sv` | fct_trips, dim_routes, dim_vehicles, dim_date |
| Finance | `finance_sv` | fct_invoices, fct_payments, dim_customers, dim_date |
| HR | `workforce_sv` | fct_shifts, dim_drivers, dim_vehicles, dim_date |

Shared dimensions (like `dim_date`) can appear in multiple semantic views.

### 2. Different Audiences With Different Vocabularies

The same data needs different semantic framing for different users.

| Audience | Semantic View | Differences |
|----------|--------------|-------------|
| Executives | `executive_sv` | High-level metrics (revenue, growth %), no operational detail |
| Operations team | `operations_sv` | Granular metrics (occupancy per trip, delays, capacity) |
| Partners/Clients | `partner_sv` | Limited scope, no cost/margin data, different synonyms |

### 3. Access Control / Data Governance

You need to restrict what certain roles can see or query.

- A **public** semantic view exposes only non-sensitive metrics
- An **internal** semantic view includes margin, cost, and employee data
- A **partner** semantic view shows only their routes/bookings

Snowflake governance (RBAC) controls who can `REFERENCES` each semantic view.

### 4. Table Count Exceeds Practical Limits

When a single semantic view has 15+ tables with complex relationships, Cortex Analyst may struggle to generate correct joins. Split by subject area to keep each view focused.

Rule of thumb: **5-10 tables per semantic view** is ideal.

### 5. Conflicting Metric Definitions

The same word means different things in different contexts.

Example: "revenue" might mean:
- **Gross revenue** (all bookings) for the finance team
- **Net revenue** (completed only, minus refunds) for operations
- **Recognized revenue** (accounting rules) for reporting

If these can't coexist cleanly as separate metrics in one view, split them.

### 6. Different Grain / Temporal Scope

Some users need real-time operational data while others need historical trends.

| View | Grain | Scope |
|------|-------|-------|
| `realtime_ops_sv` | Trip-level, today | Current day operations |
| `historical_analytics_sv` | Daily aggregates | Multi-year trends |

---

## When NOT to Split

Do **not** create separate semantic views for:

- **Minor permission differences** — use Snowflake RBAC on the underlying tables instead
- **One extra table** — just add it to the existing view
- **Different chart types** — that's a presentation concern, not a semantic one
- **Dev vs. prod** — use dbt targets/environments, not separate views

---

## Naming Convention

When you do have multiple semantic views:

```
<domain>_<audience>_sv

Examples:
  operations_sv            (single domain, general audience)
  operations_internal_sv   (full detail, internal only)
  operations_partner_sv    (restricted, external facing)
  finance_sv               (separate domain)
```

---

## How It Applies to This Project

Currently, `FLIBCO_OPERATIONS_SV` covers:

- 2 fact tables (trips, revenue)
- 3 dimension tables (routes, date, vehicles)
- 7 metrics, 20 dimensions, 6 facts

This is well within the single-view sweet spot. Consider splitting only if:

- A **finance domain** is added (costs, margins, invoicing)
- A **customer-facing portal** needs a restricted view
- A **driver/workforce domain** is added (shifts, performance)

Until then, one view is correct.
