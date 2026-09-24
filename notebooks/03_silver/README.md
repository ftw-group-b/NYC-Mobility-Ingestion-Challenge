# Silver

The three transformations run independently after Bronze validation:

1. `01_silver_green_taxi.ipynb`
2. `02_silver_taxi_zones.ipynb`
3. `03_silver_weather.ipynb`

Silver standardizes types, derives analysis fields, keeps provenance, and adds explicit quality flags. Validation remains separate under `tests/silver/`.

Each parallel Silver notebook uses `CREATE SCHEMA IF NOT EXISTS` before writing
its table, so a clean environment does not depend on a schema created by an
earlier manual run.
