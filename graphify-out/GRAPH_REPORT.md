# Graph Report - /Users/goncalo_santos/repos/flibco-agentic-analytics  (2026-05-07)

## Corpus Check
- 191 files · ~264,118 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 33 nodes · 46 edges · 9 communities detected
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 4 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Semantic View Design|Semantic View Design]]
- [[_COMMUNITY_License Header Formatting|License Header Formatting]]
- [[_COMMUNITY_dbt Snowflake Integration|dbt Snowflake Integration]]
- [[_COMMUNITY_Header File Insertion|Header File Insertion]]
- [[_COMMUNITY_Project Architecture|Project Architecture]]
- [[_COMMUNITY_Semantic Layer Planning|Semantic Layer Planning]]
- [[_COMMUNITY_dbt Utils Package|dbt Utils Package]]
- [[_COMMUNITY_License Script Entrypoint|License Script Entrypoint]]
- [[_COMMUNITY_ADR Governance|ADR Governance]]

## God Nodes (most connected - your core abstractions)
1. `apply_header_to_file()` - 6 edges
2. `FLIBCO_OPERATIONS_SV Semantic View` - 6 edges
3. `prepare_header_for_ext()` - 5 edges
4. `Flibco Agentic Analytics Project` - 5 edges
5. `Running dbt in Snowflake Guide` - 5 edges
6. `dbt_utils Package` - 4 edges
7. `main()` - 3 edges
8. `dbt_semantic_view Package` - 3 edges
9. `semantic_view Materialization` - 3 edges
10. `Prefer Native Semantic Views Over Legacy YAML` - 3 edges

## Surprising Connections (you probably didn't know these)
- `semantic_view Materialization` --semantically_similar_to--> `Dynamic Table Materialization`  [INFERRED] [semantically similar]
  dbt_packages/dbt_semantic_view/README.md → docs/dbt-in-snowflake.md
- `Flibco Project Plan (2026-05-06)` --references--> `Flibco Agentic Analytics Project`  [EXTRACTED]
  plans/plan_2026-05-06_1408.md → README.md
- `Flibco Agentic Analytics Project` --references--> `dbt_utils Package`  [EXTRACTED]
  README.md → dbt_packages/dbt_utils/README.md
- `Flibco Agentic Analytics Project` --references--> `dbt_semantic_view Package`  [EXTRACTED]
  README.md → dbt_packages/dbt_semantic_view/README.md
- `Custom generate_schema_name Macro` --rationale_for--> `Medallion Architecture (Bronze-Silver-Gold)`  [INFERRED]
  docs/dbt-in-snowflake.md → README.md

## Hyperedges (group relationships)
- **Semantic View Architecture Stack** — readme_flibco_operations_sv, dbt_semantic_view_readme_package, dbt_semantic_view_readme_materialization, plan_2026_05_06_1408_semantic_over_yaml, semantic_view_guidelines_when_to_split [EXTRACTED 0.95]
- **Medallion Architecture Data Pipeline** — readme_medallion_architecture, readme_star_schema_design, dbt_in_snowflake_generate_schema_name, dbt_utils_readme_date_spine [INFERRED 0.85]
- **dbt_utils Architecture Decision Records** — adr_0000_documenting_architecture_decisions, adr_0001_decision_record_format, adr_0002_cross_database_utils [EXTRACTED 1.00]

## Communities (9 total, 2 thin omitted)

### Community 0 - "Semantic View Design"
Cohesion: 0.47
Nodes (6): Cortex Analyst / Snowflake Intelligence Integration, FLIBCO_OPERATIONS_SV Semantic View, Star Schema Design Pattern, 5-10 Tables Per Semantic View Rule, Default to Single Semantic View Per Domain, When to Create New Semantic Views (Guidelines)

### Community 1 - "License Header Formatting"
Cohesion: 0.7
Nodes (4): format_comment_block_for_hash(), format_comment_block_for_html(), format_comment_block_for_sql(), prepare_header_for_ext()

### Community 2 - "dbt Snowflake Integration"
Cohesion: 0.5
Nodes (5): Dynamic Table Materialization, Running dbt in Snowflake Guide, Key Pair Authentication for CI/CD, semantic_view Materialization, dbt_semantic_view Package

### Community 3 - "Header File Insertion"
Cohesion: 0.5
Nodes (4): apply_header_to_file(), has_header(), insert_after_doctype(), insert_after_shebang_and_encoding()

### Community 4 - "Project Architecture"
Cohesion: 0.67
Nodes (3): Custom generate_schema_name Macro, Flibco Agentic Analytics Project, Medallion Architecture (Bronze-Silver-Gold)

### Community 5 - "Semantic Layer Planning"
Cohesion: 0.67
Nodes (3): Flibco Project Plan (2026-05-06), Prefer Native Semantic Views Over Legacy YAML, Native Snowflake Semantic View Layer

### Community 6 - "dbt Utils Package"
Cohesion: 0.67
Nodes (3): ADR-0002: Cross-Database Utils Migration to dbt Core, dbt_utils date_spine Macro, dbt_utils Package

## Knowledge Gaps
- **7 isolated node(s):** `Native Snowflake Semantic View Layer`, `Star Schema Design Pattern`, `dbt_utils date_spine Macro`, `ADR-0000: Documenting Architecture Decisions`, `ADR-0001: Format and Structure of Decision Records (MADR)` (+2 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `FLIBCO_OPERATIONS_SV Semantic View` connect `Semantic View Design` to `dbt Snowflake Integration`, `Project Architecture`, `Semantic Layer Planning`?**
  _High betweenness centrality (0.185) - this node is a cross-community bridge._
- **Why does `Flibco Agentic Analytics Project` connect `Project Architecture` to `Semantic View Design`, `dbt Snowflake Integration`, `Semantic Layer Planning`, `dbt Utils Package`?**
  _High betweenness centrality (0.148) - this node is a cross-community bridge._
- **Why does `dbt_utils Package` connect `dbt Utils Package` to `dbt Snowflake Integration`, `Project Architecture`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **What connects `Native Snowflake Semantic View Layer`, `Star Schema Design Pattern`, `dbt_utils date_spine Macro` to the rest of the system?**
  _7 weakly-connected nodes found - possible documentation gaps or missing edges._