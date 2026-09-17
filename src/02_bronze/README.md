# Bronze Source Queries

- `00_create_bronze_schema.sql`: creates the Bronze schema.
- `01_ingestion_log.sql`: creates and updates the idempotent batch log.
- `02_green_taxi.sql`: creates and incrementally loads Green Taxi.
- `03_taxi_zones.sql`: creates and loads the Taxi Zone lookup.
- `04_weather_raw.sql`: creates and loads the raw Weather payload.

Validation queries are maintained in `tests/bronze/`.
