-- =============================================================================
-- RBAC for Flibco Analytics Agent Skills
-- =============================================================================
-- This script configures role-based access control to ensure only developers
-- can create/modify skills on the agent, while analysts can only invoke them.
--
-- Privilege model:
--   DATA_ENGINEER: MODIFY agent + READ/WRITE skill stage (full skill lifecycle)
--   ANALYST:       USAGE on agent only (invoke skills via Snowflake Intelligence)
-- =============================================================================

-- Skill stage: stores SKILL.md files and supporting scripts
CREATE STAGE IF NOT EXISTS FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE
  DIRECTORY = (ENABLE = TRUE)
  COMMENT = 'Stage for Cortex Agent skill files. Only DATA_ENGINEER role can write.';

-- =============================================================================
-- Developer privileges (DATA_ENGINEER role)
-- Can: create skills, upload to stage, modify agent spec, monitor feedback
-- =============================================================================
GRANT USAGE ON DATABASE FLIBCO_ANALYTICS TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA FLIBCO_ANALYTICS.PUBLIC TO ROLE DATA_ENGINEER;

-- Stage access: read + write skill files
GRANT READ ON STAGE FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE TO ROLE DATA_ENGINEER;
GRANT WRITE ON STAGE FLIBCO_ANALYTICS.PUBLIC.SKILL_STAGE TO ROLE DATA_ENGINEER;

-- Agent access: modify spec (add/remove skills), monitor feedback
GRANT MODIFY ON AGENT FLIBCO_ANALYTICS.PUBLIC.FLIBCO_ANALYTICS_AGENT TO ROLE DATA_ENGINEER;
GRANT MONITOR ON AGENT FLIBCO_ANALYTICS.PUBLIC.FLIBCO_ANALYTICS_AGENT TO ROLE DATA_ENGINEER;

-- =============================================================================
-- Analyst privileges (ANALYST role)
-- Can: invoke agent + skills via Snowflake Intelligence, give feedback
-- Cannot: modify agent, upload skills, read observability events
-- =============================================================================
GRANT USAGE ON DATABASE FLIBCO_ANALYTICS TO ROLE ANALYST;
GRANT USAGE ON SCHEMA FLIBCO_ANALYTICS.PUBLIC TO ROLE ANALYST;

-- Agent access: invoke only (no MODIFY, no MONITOR)
GRANT USAGE ON AGENT FLIBCO_ANALYTICS.PUBLIC.FLIBCO_ANALYTICS_AGENT TO ROLE ANALYST;

-- Required database role for Cortex Agent API access
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_AGENT_USER TO ROLE ANALYST;
