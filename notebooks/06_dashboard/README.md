# Data Quality Views

`01_data_quality_dashboard_views.ipynb` is the documented, compiled Databricks notebook used by the job. It creates the nine monitoring views required by the Data Quality Dashboard.

The individual view queries remain in `src/06_data_quality/`. Validation and the consolidated release decision remain under `tests/`, avoiding duplicate Data Quality and quality-gate notebook folders.
