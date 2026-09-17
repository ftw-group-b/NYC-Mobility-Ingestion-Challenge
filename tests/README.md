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
| End to end | `end_to_end/01_end_to_end_quality_gate.ipynb` |

The consolidated quality gate uses the layer results and governed dashboard checks to produce one PASS/FAIL release decision.
