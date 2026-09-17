# Repository Structure

The repository has three clear code areas.

## `notebooks/` — compiled workflow

These are the documented, runnable Databricks assets used by the job:

| Folder | Responsibility |
|---|---|
| `00_source_inspection` | Raw-source profiling |
| `01_ingestion` | Incremental source acquisition |
| `02_bronze` | Compiled Bronze setup and loads |
| `03_silver` | Compiled Silver transformations |
| `04_gold` | Compiled star-schema creation |
| `05_analytics` | Compiled business-question views |
| `06_dashboard` | Compiled Data Quality Dashboard views |

## `src/` — modular table queries

This is the modular source library. Ingestion is split by external source, while Bronze, Silver, Gold, Analytics, and Data Quality are split into one table or view per SQL file. It is easier to review one source or table here than inside a full layer notebook.

## `tests/` — validation by layer

Executable checks are grouped into:

- `bronze/`
- `silver/`
- `gold/`
- `analytics/`
- `end_to_end/`

The final end-to-end test publishes the consolidated quality result and fails the Databricks task when a critical condition returns `FAIL`.

## Naming standard

- ordered execution folders and files use a two-digit numeric prefix; shared helpers use descriptive names;
- implementation names use lowercase `snake_case`;
- table and view names match their Gold or Silver objects; and
- `README.md` is the only intentional uppercase filename.

Duplicate numbered/un-numbered notebooks, duplicate test documents, and retired placeholder code are excluded from the clean delivery.
