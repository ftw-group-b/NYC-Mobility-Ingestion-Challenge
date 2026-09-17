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
| Layer-specific SQL results | `notebooks/05_validation/` |
| Analytics validation | `notebooks/07_analytics_validation/` |
| Consolidated PASS/FAIL | `notebooks/09_quality_gate/` |
| Dashboard monitoring views | `notebooks/08_data_quality/` |
| CI structure checks | `.github/workflows/ci.yml` |
| Bundle deployment | `.github/workflows/deploy-databricks.yml` |

The repository documentation describes verified conditions and acceptance rules without inventing numerical output that is not stored in the project files.
