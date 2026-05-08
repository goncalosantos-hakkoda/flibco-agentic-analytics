# Flibco Analytics Agent

## Agent Details

| Property | Value |
|----------|-------|
| **Name** | `FLIBCO_ANALYTICS_AGENT` |
| **Database** | `FLIBCO_ANALYTICS` |
| **Schema** | `PUBLIC` |
| **Skill Stage** | `@FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE` |

## Tools

| Tool | Type | Semantic View |
|------|------|---------------|
| `flibco_operations_analyst` | `cortex_analyst_text_to_sql` | `FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_OPERATIONS_SV` |
| `FLIBCO_PUNCTUALITY_SV` | `cortex_analyst_text_to_sql` | `FLIBCO_ANALYTICS.SEMANTIC.FLIBCO_PUNCTUALITY_SV` |

## Skills

| Skill | Folder | Description |
|-------|--------|-------------|
| `route_report` | `skills/route_report/` | Route performance report combining operations + punctuality |
| `revenue_at_risk` | `skills/revenue_at_risk/` | Revenue at risk from delay cost correlation |

## Deploying Skills

```bash
# Upload a skill to the stage
snow stage put skills/route_report/SKILL.md \
  @FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE/skills/route_report/ --overwrite

# Or with SQL
PUT file:///path/to/skills/route_report/SKILL.md \
  @FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE/skills/route_report/;
```

Then attach via `ALTER AGENT` (see `docs/agent-skills.md` for full instructions).

## Monitoring Feedback

```sql
SELECT timestamp, VALUE:feedback_message::VARCHAR, VALUE:positive::VARCHAR
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
  'FLIBCO_ANALYTICS', 'PUBLIC', 'FLIBCO_ANALYTICS_AGENT', 'CORTEX AGENT'
))
WHERE RECORD:name = 'CORTEX_AGENT_FEEDBACK'
ORDER BY timestamp DESC
LIMIT 20;
```

## Shared Dimensions

Both semantic views share `dim_routes`, `dim_vehicles`, and `dim_date`, enabling cross-domain queries like "What's the occupancy rate on routes with poor OTP?"
