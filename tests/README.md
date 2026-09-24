# Validation Notebooks

Validation is separated from creation and grouped by pipeline layer.

| Scope | Executable validation |
|---|---|
| Bronze | `bronze/01_bronze_validation.ipynb` |
| Silver Green Taxi | `silver/01_green_taxi_validation.ipynb` |
| Silver Taxi Zones | `silver/02_taxi_zones_validation.ipynb` |
| Silver Weather | `silver/03_weather_validation.ipynb` |
| Gold | `gold/01_gold_mart_validation.ipynb` |
| Business Analytics | `analytics/01_analytics_validation.ipynb` |
| End to end | `end_to_end/02_great_expectations_quality_gate.ipynb` |
| Local unit and mirror alignment | `unit/test_*.py` |

The active consolidated gate calculates and publishes 14 governed checks, then uses Great Expectations to verify that the complete check set is present and every status is `PASS`. A failed expectation stops the Databricks task. The earlier SQL-only gate is archived under `docs/archive/` and is not executable or deployed.

The local unit tests verify first-write-wins ingestion, trusted-sidecar failure,
transient HTTP retry behavior, and source/notebook alignment without using the
network. CI executes these tests on every pull request.
