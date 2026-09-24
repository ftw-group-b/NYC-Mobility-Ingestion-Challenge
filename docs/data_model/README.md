# Gold Data Model and Dictionary

![Gold star schema](../assets/star_schema.svg)

## Model grain

- `fact_green_taxi_trip`: one accepted Silver Green Taxi source record
- `dim_date`: one calendar date required by a pickup or drop-off
- `dim_time`: one Unknown member plus one member for each hour from 00:00 to 23:00
- `dim_taxi_zone`: one official TLC `LocationID`
- `dim_weather_hour`: one Unknown member plus one accepted local Weather hour

## Relationships

| Fact foreign key | Dimension key | Role |
|---|---|---|
| `pickup_date_key` | `dim_date.date_key` | Pickup calendar date |
| `dropoff_date_key` | `dim_date.date_key` | Drop-off calendar date |
| `pickup_time_key` | `dim_time.time_key` | Pickup hour |
| `dropoff_time_key` | `dim_time.time_key` | Drop-off hour |
| `pickup_taxi_zone_key` | `dim_taxi_zone.taxi_zone_key` | Pickup area |
| `dropoff_taxi_zone_key` | `dim_taxi_zone.taxi_zone_key` | Drop-off area |
| `pickup_weather_hour_key` | `dim_weather_hour.weather_hour_key` | Weather at pickup hour |

## `fact_green_taxi_trip`

| Column | Type | Meaning |
|---|---|---|
| `trip_key` | BIGINT | Deterministic technical fact-row key |
| `vendor_id` | BIGINT | TLC technology provider code |
| `pickup_datetime` | TIMESTAMP_NTZ | Local pickup timestamp |
| `dropoff_datetime` | TIMESTAMP_NTZ | Local drop-off timestamp |
| `pickup_date_key` | INT | Pickup date key in `yyyyMMdd` form |
| `dropoff_date_key` | INT | Drop-off date key in `yyyyMMdd` form |
| `pickup_time_key` | INT | Pickup-hour key; 0 is Unknown and 1-24 represent 00:00-23:00 |
| `dropoff_time_key` | INT | Drop-off-hour key using the same convention |
| `pickup_taxi_zone_key` | INT | Pickup TLC LocationID |
| `dropoff_taxi_zone_key` | INT | Drop-off TLC LocationID |
| `pickup_weather_hour_key` | BIGINT | Pickup Weather hour; 0 is Unknown |
| `trip_count` | BIGINT | Constant 1 for additive trip counting |
| `passenger_count` | BIGINT | Reported passenger count |
| `trip_distance` | DOUBLE | Reported trip distance in miles |
| `trip_duration_minutes` | DOUBLE | Derived nonnegative duration in minutes |
| `trip_average_speed_mph` | DOUBLE | Distance divided by valid positive duration |
| `total_amount_per_mile` | DOUBLE | Total amount divided by positive trip distance |
| `fare_amount` | DOUBLE | Metered fare |
| `extra` | DOUBLE | TLC extra charges |
| `mta_tax` | DOUBLE | MTA tax |
| `tip_amount` | DOUBLE | Reported tip |
| `tolls_amount` | DOUBLE | Reported tolls |
| `improvement_surcharge` | DOUBLE | TLC improvement surcharge |
| `congestion_surcharge` | DOUBLE | Congestion surcharge |
| `cbd_congestion_fee` | DOUBLE | CBD congestion fee |
| `total_amount` | DOUBLE | Total reported trip amount |
| `payment_type` | BIGINT | TLC payment code |
| `payment_type_description` | STRING | Readable payment label |
| `trip_type` | BIGINT | Street-hail or dispatch classification |
| `rate_code_id` | BIGINT | TLC rate-code identifier |
| `store_and_fwd_flag` | STRING | Store-and-forward indicator |
| `dq_zero_trip_distance` | BOOLEAN | Trip distance equals zero |
| `dq_extreme_trip_distance` | BOOLEAN | Trip distance exceeds the agreed profiling limit |
| `dq_negative_trip_distance` | BOOLEAN | Trip distance is negative |
| `dq_out_of_range_datetime` | BOOLEAN | Pickup/drop-off is outside March-May analytical scope |
| `dq_invalid_trip_duration` | BOOLEAN | Drop-off occurs before pickup |
| `dq_missing_weather_coverage` | BOOLEAN | No accepted Weather hour matched the pickup hour |
| `source_system` | STRING | Originating system |
| `source_file` | STRING | Originating source file |
| `batch_id` | STRING | Ingestion batch identifier |

`trip_key` supports repeatable row-level identification. It is not claimed as a unique identifier assigned by TLC to a real-world trip.

## `dim_date`

| Column | Type | Meaning |
|---|---|---|
| `date_key` | INT | Calendar key in `yyyyMMdd` form |
| `full_date` | DATE | Calendar date |
| `year` | INT | Year |
| `quarter` | INT | Quarter number |
| `month_number` | INT | Month number |
| `month_name` | STRING | Month name |
| `day_of_month` | INT | Day of month |
| `day_name` | STRING | Weekday name |
| `day_of_week` | INT | Databricks weekday number |
| `is_weekend` | BOOLEAN | Saturday or Sunday flag |
| `is_holiday` | BOOLEAN | Reserved nullable field; no unverified holiday label is assigned |

## `dim_time`

| Column | Type | Meaning |
|---|---|---|
| `time_key` | INT | 0 for Unknown; 1-24 for real hours |
| `hour_24` | INT | Clock hour from 0 to 23 |
| `hour_label` | STRING | Display label such as `08:00` |
| `day_period` | STRING | `AM`, `PM`, or `Unknown` |

## `dim_taxi_zone`

| Column | Type | Meaning |
|---|---|---|
| `taxi_zone_key` | INT | Official TLC LocationID reused as the dimension key |
| `location_id` | INT | Official TLC LocationID |
| `borough` | STRING | NYC borough label |
| `zone_name` | STRING | Taxi Zone name |
| `service_zone` | STRING | TLC service-zone grouping |

## `dim_weather_hour`

| Column | Type | Meaning |
|---|---|---|
| `weather_hour_key` | BIGINT | 0 for Unknown; otherwise `yyyyMMddHH` local-hour key |
| `weather_timestamp_local` | TIMESTAMP_NTZ | Source-provided local-hour label |
| `temperature_2m` | DOUBLE | Temperature at two metres |
| `precipitation` | DOUBLE | Total precipitation |
| `rain` | DOUBLE | Rain amount |
| `snowfall` | DOUBLE | Snowfall amount |
| `weather_code` | BIGINT | Open-Meteo WMO weather code |
| `wind_speed_10m` | DOUBLE | Wind speed at ten metres |
| `timezone` | STRING | Source timezone |
| `latitude` | DOUBLE | Weather-grid latitude |
| `longitude` | DOUBLE | Weather-grid longitude |
| `utc_offset_seconds` | BIGINT | Source UTC offset |
| `source_system` | STRING | Weather provider |
| `source_file` | STRING | Approved JSON source file |
| `batch_id` | STRING | Ingestion batch identifier |
