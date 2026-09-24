# Architecture and Pipeline

## Databricks job pipeline

![Implemented Databricks pipeline](../assets/pipeline_architecture.svg)

## Group B architecture overview

![Group B architecture and pipeline](../assets/pipeline_architecture_group_b.svg)

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
- `tests/` contains unit, source-to-notebook alignment, Bronze, Silver, Gold, Analytics, and end-to-end validation.

## Change-alignment contract

The runnable notebooks, modular source, tests, and documentation describe one pipeline and must change together:

```text
src change -> compiled notebook change -> focused test change -> CI validation -> documentation update
```

- `src/` is the small, reviewable implementation.
- `notebooks/` is the compiled workflow deployed to Databricks.
- `tests/unit/` protects rerun behavior and checks critical source-to-notebook contracts.
- layer tests and the Great Expectations gate validate data after deployment.
- `docs/` records the reason, expected behavior, and recovery procedure.

CI runs the unit and alignment tests so an ingestion or Bronze change cannot be accepted when its source and compiled notebook disagree.

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

Green Taxi is loaded month by month. Raw landing follows a first-write-wins rule: an existing deterministic file is verified against its metadata sidecar and returned as `IDEMPOTENT_SKIP` without another download or overwrite. Bronze inserts a source file only when its stable identifier is not already present. The same guards are used for Taxi Zones and Weather, allowing safe reruns without duplicate files or rows. A deliberate source revision must use a new versioned filename.

Silver and Gold use deterministic full-refresh builds at the current course scale. Re-running them recreates the same business rows from the accepted upstream data. Audit timestamps are excluded from logical idempotency comparisons.

## Failure behavior

Validation tasks are placed directly after the layer they protect. The final Great Expectations notebook consolidates the governed checks and raises an exception when an expectation fails, stopping the Databricks job before the delivery is treated as healthy.

## Rerun incident and recovery

The first pipeline run succeeded, but a later rerun exposed two idempotency gaps before the Great Expectations task was reached. GX did not cause either incident; it remains the final quality gate.

| Stage | Problem encountered | Resolution | Long-term behavior |
|---|---|---|---|
| Ingestion | Open-Meteo could return different bytes for the same deterministic filename. The old logic downloaded again and rejected the existing file as different. | Apply first-write-wins: validate an existing local file against its SHA-256 metadata and return `IDEMPOTENT_SKIP` without calling the source again. | Repeated runs reuse the verified raw file. An intentional source revision must use a new versioned filename. A hash mismatch still fails safely. |
| Bronze load | The old `WHERE NOT EXISTS` filter could still make Spark inspect the source, while `SELECT src.*` depended on column position. | Check the target for the `source_file` before reading the source, skip an already-loaded batch, insert new rows `BY NAME`, and disable schema evolution for controlled sources. | Repeated batches do not create duplicates. Unexpected schema changes stop visibly instead of being silently accepted. |

After both changes were merged, CI, deployment, and the manual source-to-Gold pipeline run completed successfully. This runtime result confirms the current rerun path; the unit and alignment tests protect the same contract on future changes.

## Dashboards

- The **Data Quality Dashboard** reads the `dq_dashboard_*` views.
- The **Business-Ready Analytics Dashboard** reads the `analytics_*` views.

Dashboard SQL is separated from the Gold build so business questions do not change the dimensional model.
