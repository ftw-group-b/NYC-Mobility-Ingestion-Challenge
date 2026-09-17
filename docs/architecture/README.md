# Architecture and Pipeline

![Implemented Databricks pipeline](../assets/pipeline_architecture.svg)

## Design

The project uses the Databricks medallion pattern:

- **Ingestion** copies or requests the approved source data and records a stable source identifier.
- **Bronze** preserves source values and adds provenance. Repeated files are skipped through ingestion-log guards.
- **Silver** standardizes data types, derives useful fields, and adds explicit data-quality flags while keeping lineage.
- **Gold** creates one trip fact and four reusable dimensions.
- **Analytics** publishes dashboard-ready views from Gold.
- **Validation** checks every layer and ends with one consolidated PASS/FAIL gate.

## Code organization

- `notebooks/` contains the compiled Databricks workflow from ingestion through dashboard-view creation.
- `src/` contains modular source acquisition and one table/view query per file.
- `tests/` contains executable validation grouped by Bronze, Silver, Gold, Analytics, and end-to-end scope.

## Databricks task flow

```text
Ingestion -> Bronze setup -> Bronze load -> Bronze validation
  ├─> Silver Green Taxi -> Silver Green Taxi validation ─┐
  ├─> Silver Taxi Zones -> Silver Taxi Zones validation ─┼─> Gold creation -> Gold validation
  └─> Silver Weather    -> Silver Weather validation ────┘                        │
                                                                                 ├─> Data-quality views ──────────────────────────────┐
                                                                                 └─> Business analytics views -> Analytics validation ├─> Consolidated quality gate
                                                                                                                     ├─> Data Quality Dashboard
                                                                                                                     └─> Business Analytics Dashboard
```

The three Silver branches run independently after Bronze validation. Gold begins when all three Silver validations pass.

## Storage and schemas

| Stage | Databricks location |
|---|---|
| Landing files | R2 / Databricks Volume used by ingestion |
| Bronze tables | `ftw-week-08.01_bronze` |
| Silver tables | `ftw-week-08.02_silver` |
| Gold tables and views | `ftw-week-08.03_gold` |

## Incremental and idempotent behavior

Green Taxi is loaded month by month. A source file is inserted only when its stable source identifier is absent from the ingestion log. The same guard is used for Taxi Zones and Weather. This allows April and May to be added without rebuilding March and prevents the same file from being loaded twice.

Silver and Gold use deterministic full-refresh builds at the current course scale. Re-running them recreates the same business rows from the accepted upstream data. Audit timestamps are excluded from logical idempotency comparisons.

## Failure behavior

Validation tasks are placed directly after the layer they protect. The final quality-gate notebook consolidates critical checks and calls `assert_true`; any FAIL result stops the Databricks job before the delivery is treated as healthy.

## Dashboards

- The **Data Quality Dashboard** reads the `dq_dashboard_*` views.
- The **Business-Ready Analytics Dashboard** reads the `analytics_*` views.

Dashboard SQL is separated from the Gold build so business questions do not change the dimensional model.
