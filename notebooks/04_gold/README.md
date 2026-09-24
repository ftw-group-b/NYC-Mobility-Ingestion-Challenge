# Gold

`01_gold_mart_creation.ipynb` creates four dimensions and `fact_green_taxi_trip` after all Silver validations pass.

The fact retains one accepted Silver row per record and exposes reusable
derived measures including `trip_average_speed_mph` and
`total_amount_per_mile`. Dashboard-specific queries remain in the Analytics
layer.
