# Flibco Agentic Analytics

## Project Context

Before answering architecture, "where is X?", or relationship questions, check `graphify-out/graph.json` first. This knowledge graph contains 33 nodes across 9 communities covering the full project structure — semantic views, dbt integration, medallion architecture, and tooling.

Use `/graphify query "<question>"` to traverse the graph and get relevant nodes with source locations instead of reading all source files. Only read source files when you need code-level detail beyond what the graph provides.

Key god nodes (most connected concepts):
- `FLIBCO_OPERATIONS_SV Semantic View` — bridges semantic view design, dbt integration, and project architecture
- `Flibco Agentic Analytics Project` — central project node connecting all domains
- `Running dbt in Snowflake Guide` — dbt configuration and materialization patterns

## Stack

- dbt-core on Snowflake
- Medallion architecture (bronze/silver/gold)
- Snowflake native semantic views (not legacy YAML)
- Python scripts for tooling (license headers)
