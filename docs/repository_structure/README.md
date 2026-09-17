# Repository Structure

The repository has one canonical location for each responsibility:

| Folder | Responsibility |
|---|---|
| `notebooks/00_source_inspection` | Raw-source profiling |
| `notebooks/01_ingestion` | Incremental source acquisition |
| `notebooks/02_bronze` | Raw Delta setup and loading |
| `notebooks/03_silver` | Typed, standardized source tables |
| `notebooks/04_gold` | Star-schema creation only |
| `notebooks/05_validation` | Bronze, Silver, and Gold validation |
| `notebooks/06_analytics` | Business-question views only |
| `notebooks/07_analytics_validation` | Independent analytics checks |
| `notebooks/08_data_quality` | Data Quality Dashboard views |
| `notebooks/09_quality_gate` | Consolidated end-to-end PASS/FAIL |
| `dashboard` | Dashboard purpose and page guidance |
| `docs` | Architecture, model, quality, and decisions |
| `resources` | Databricks job definition |
| `tests` | Human-readable validation map |

## Naming standard

- execution folders and files use a two-digit numeric prefix;
- implementation names use lowercase `snake_case`;
- each executable asset appears once; and
- `README.md` is the only intentional uppercase filename.

## Cleanup applied

The active implementation was consolidated under `notebooks/`. Duplicate numbered/un-numbered notebooks, duplicate hyphen/underscore test documents, the mixed `06_dashboard` folder, and the legacy placeholder `src/` tree are excluded from this clean delivery. Analytics, Analytics Validation, Data Quality, and the consolidated Quality Gate now have separate folders and job stages.

Upload the contents of the clean repository root as one unit. Replacing the old tree prevents retired duplicates from remaining beside the canonical files.
