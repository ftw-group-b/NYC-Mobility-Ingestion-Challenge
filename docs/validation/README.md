# Final Validation

The final validation is complete when the deployed Databricks job finishes with all tasks successful and the consolidated quality gate returns `PASS`.

## Required conditions

- all required source batches are represented in Bronze
- Bronze provenance is complete
- Silver preserves the accepted Bronze population for each source
- Gold preserves the accepted Silver trip population
- dimension keys are unique
- fact foreign keys resolve without multiplying rows
- analytics views preserve their declared grains
- dashboard trip totals reconcile with the in-scope Gold fact
- lineage fields remain available in the fact table

## Evidence locations

| Evidence | Location |
|---|---|
| Local rerun and source-to-notebook contract tests | `tests/unit/` |
| Layer-specific validation | `tests/bronze/`, `tests/silver/`, and `tests/gold/` |
| Analytics validation | `tests/analytics/` |
| Consolidated PASS/FAIL notebook | `tests/end_to_end/02_great_expectations_quality_gate.ipynb` |
| Dashboard monitoring views | `notebooks/06_dashboard/` |
| CI structure, syntax, unit, and alignment checks | `.github/workflows/ci.yml` |
| Bundle deployment | `.github/workflows/deploy-databricks.yml` |

The repository documentation describes verified conditions and acceptance rules without inventing numerical output that is not stored in the project files.

The final notebook publishes 14 governed results for the dashboard, then Great Expectations verifies the result contract and stops the task when any expectation fails.
