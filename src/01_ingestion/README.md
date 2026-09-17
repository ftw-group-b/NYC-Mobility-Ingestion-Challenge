# Ingestion Source Modules

- `common.py`: shared idempotent download, hashing, and metadata helper.
- `01_green_taxi.py`: monthly Green Taxi acquisition.
- `02_taxi_zones.py`: Taxi Zone lookup acquisition.
- `03_weather.py`: monthly Open-Meteo acquisition.

The compiled Databricks notebook is `notebooks/01_ingestion/01_ingestion.ipynb`.
