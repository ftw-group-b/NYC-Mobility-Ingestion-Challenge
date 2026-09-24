# Bronze

1. `01_bronze_setup.ipynb` creates the Bronze schema, raw tables, and ingestion log.
2. `02_bronze_load.ipynb` performs guarded incremental loads and records validated ingestion receipts.

Bronze keeps source values and adds provenance. Data cleaning begins in Silver.
Before reading a source, the load notebook checks whether its stable
`source_file` is already present. Reruns return `IDEMPOTENT_SKIP`; new files use
name-based column alignment and must produce at least one Bronze row.
