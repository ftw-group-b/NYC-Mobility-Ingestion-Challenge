# Gold Source Queries

Gold is split into one file per dimensional table:

- `01_dim_date.sql`
- `02_dim_time.sql`
- `03_dim_taxi_zone.sql`
- `04_dim_weather_hour.sql`
- `05_fact_green_taxi_trip.sql`

Validation queries are maintained in `tests/gold/`.
