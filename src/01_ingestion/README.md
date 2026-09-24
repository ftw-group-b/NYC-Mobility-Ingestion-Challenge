# Ingestion Source Modules

- `common.py`: shared first-write-wins landing, hashing, and metadata helper.
- `01_green_taxi.py`: monthly Green Taxi acquisition.
- `02_taxi_zones.py`: Taxi Zone lookup acquisition.
- `03_weather.py`: monthly Open-Meteo acquisition.

The compiled Databricks notebook is `notebooks/01_ingestion/01_ingestion.ipynb`.

On a rerun, `common.py` validates an existing raw file against its SHA-256
metadata sidecar and returns `IDEMPOTENT_SKIP` without making another network
request. A deliberate source revision must use a new versioned filename.
