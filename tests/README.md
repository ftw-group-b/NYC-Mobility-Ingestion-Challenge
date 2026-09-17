# Validation Evidence Map

Validation is implemented as executable Databricks test artifacts and summarized here for reviewers.

| Scope | Executable validation | Review guide |
|---|---|---|
| Bronze | `tests/bronze/01_bronze_validation.ipynb` | `tests/bronze/01_bronze_validation.md` |
| Silver Green Taxi | `tests/silver/01_green_taxi_validation.ipynb` | `tests/silver/01_green_taxi_validation.md` |
| Silver Taxi Zones | `tests/silver/02_taxi_zones_validation.ipynb` | `tests/silver/02_taxi_zones_validation.md` |
| Silver Weather | `tests/silver/03_weather_validation.ipynb` | `tests/silver/03_weather_validation.md` |
| Gold | `tests/gold/01_gold_mart_validation.ipynb` | `tests/gold/01_gold_mart_validation.md` |
| Analytics | `tests/analytics/01_analytics_validation.sql` | `tests/analytics/01_analytics_validation.md` |
| End to end | `tests/end_to_end/01_end_to_end_quality_gate.sql` | `tests/end_to_end/01_end_to_end_quality_gate.md` |

The consolidated quality gate fails the Databricks task when a critical check returns `FAIL`. It stores both detailed checks and a one-row summary for dashboards and operational review.
