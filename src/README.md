# Modular SQL Source

This folder contains the pipeline logic broken into small, reviewable SQL files. Each file owns one table or view, except `ingestion_log.sql`, which owns the shared batch-receipt log.

```text
src/
├── 01_ingestion/    # Source-specific acquisition modules
├── 02_bronze/       # Bronze schemas, tables, and guarded loads
├── 03_silver/       # One transformation per Silver table
├── 04_gold/         # One dimension or fact build per file
├── 05_analytics/    # One business view per file
└── 06_data_quality/ # One monitoring view per file
```

The corresponding files under `notebooks/` are the compiled, documented Databricks workflow. Validation belongs under `tests/`.

## Change workflow

1. Update the table-level SQL in `src/`.
2. Apply the same approved logic to its compiled notebook.
3. Run the matching layer tests.
4. Run the end-to-end quality gate.

Numeric prefixes preserve dependency order within a layer.
