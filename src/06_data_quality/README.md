# Data Quality Source Queries

The Data Quality Dashboard model is split into one file per monitoring view. The numeric order resolves dependencies, beginning with referential integrity and ending with zone hotspots.

The compiled dashboard build is `notebooks/06_dashboard/01_data_quality_dashboard_views.ipynb`. The final release decision is in `tests/end_to_end/01_end_to_end_quality_gate.ipynb`.
