# Flibco Agent Skills Guide

## Overview

This document covers the operational workflow for creating, deploying, and managing skills on the `FLIBCO_ANALYTICS_AGENT` Cortex Agent. It also describes the RBAC model, feedback monitoring, and the analyst-to-developer request process.

**Agent**: `FLIBCO_ANALYTICS.PUBLIC.FLIBCO_ANALYTICS_AGENT`  
**Skill Stage**: `FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE`  
**Skills Source**: `agents/flibco_analytics_agent/skills/` (this repo)

---

## RBAC Model

| Role | Agent Privilege | Stage Privilege | Can Do |
|------|----------------|-----------------|--------|
| `DATA_ENGINEER` | MODIFY + MONITOR | READ + WRITE | Create/update/remove skills, monitor feedback |
| `ANALYST` | USAGE only | None | Invoke agent and skills via Snowflake Intelligence |

**Key principle**: Only `DATA_ENGINEER` can alter the agent specification or upload skill files. Analysts interact through the Snowflake Intelligence UI exclusively.

Run `agents/flibco_analytics_agent/setup/rbac.sql` to apply these grants.

---

## Skill Development Workflow

### 1. Create the skill locally

Create a folder in `agents/flibco_analytics_agent/skills/<skill_name>/` with a `SKILL.md` file:

```markdown
---
name: my_skill
description: Brief summary the agent uses to decide when this skill is relevant
---

## Instructions

Detailed step-by-step instructions for the agent...
```

If the skill needs Python code, place the script in the same folder as `SKILL.md`.

### 2. Upload to Snowflake stage

```sql
PUT file:///path/to/skills/my_skill/SKILL.md
  @FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE/skills/my_skill/;
```

### 3. Attach to agent

```sql
ALTER AGENT FLIBCO_ANALYTICS.PUBLIC.FLIBCO_ANALYTICS_AGENT
  MODIFY LIVE VERSION
  SET SPECIFICATION = $$
  {
    // Include ALL existing tools + the new skill
    "skills": [
      {
        "name": "my_skill",
        "source": {
          "type": "STAGE",
          "path": "@FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE/skills/my_skill"
        }
      }
    ]
  }
  $$;
```

### 4. Verify

```sql
DESCRIBE AGENT FLIBCO_ANALYTICS.PUBLIC.FLIBCO_ANALYTICS_AGENT;
```

Skills are immediately available in Snowflake Intelligence after attachment. Analysts can explicitly select a skill via the `+` button in the Intelligence UI.

---

## Updating Skills

To update a skill's behavior, modify the `SKILL.md` file locally, re-upload with PUT (overwrites), and the agent uses the new version on next invocation. No `ALTER AGENT` needed for content updates — only for adding/removing skills.

---

## Feedback Monitoring

Snowflake Intelligence automatically captures user feedback (thumbs up/down + optional message) in the AI observability events. Developers with the `MONITOR` privilege can query it.

### Query negative feedback (discrepancy reports)

```sql
SELECT
  timestamp,
  RESOURCE_ATTRIBUTES:"snow.user.name"::VARCHAR AS user_name,
  VALUE:categories[0]::VARCHAR AS category,
  VALUE:feedback_message::VARCHAR AS feedback_message,
  VALUE:positive::VARCHAR AS is_positive
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
  'FLIBCO_ANALYTICS', 'PUBLIC', 'FLIBCO_ANALYTICS_AGENT', 'CORTEX AGENT'
))
WHERE RECORD:name = 'CORTEX_AGENT_FEEDBACK'
  AND VALUE:positive = 'false'
ORDER BY timestamp DESC;
```

### Query all feedback

```sql
SELECT
  timestamp,
  RESOURCE_ATTRIBUTES:"snow.user.name"::VARCHAR AS user_name,
  VALUE:feedback_message::VARCHAR AS feedback_message,
  VALUE:positive::VARCHAR AS is_positive
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_OBSERVABILITY_EVENTS(
  'FLIBCO_ANALYTICS', 'PUBLIC', 'FLIBCO_ANALYTICS_AGENT', 'CORTEX AGENT'
))
WHERE RECORD:name = 'CORTEX_AGENT_FEEDBACK'
ORDER BY timestamp DESC;
```

---

## Analyst Skill Request Process

When an analyst needs a capability the agent doesn't have:

1. **In Snowflake Intelligence**: The analyst gives feedback (thumbs down) with a message describing what they need (e.g., "I wish I could get a route performance report with delays included")
2. **Developer reviews**: Dev team periodically queries `CORTEX_AGENT_FEEDBACK` events (see above) to identify capability gaps
3. **Developer builds**: Creates the skill locally in this repo, tests, and deploys
4. **Analyst is notified**: The new skill appears in the Intelligence UI's `+` menu

---

## Discrepancy Reporting

When an analyst notices incorrect data from the agent:

1. **In Snowflake Intelligence**: Click thumbs down and describe the discrepancy (e.g., "Revenue for RT003 looks wrong — expected ~50K but showing 200K")
2. **Developer investigates**: Query negative feedback filtered by data-quality keywords
3. **Fix**: Correct the underlying model/data, redeploy

---

## Available Skills

| Skill | Description | Status |
|-------|-------------|--------|
| `route_report` | Comprehensive route performance report combining operations + punctuality | Active |
| `revenue_at_risk` | Revenue at risk calculator from delay cost correlation | Active |
