-- Databricks notebook source
-- Modular source: Gold Green Taxi fact (incremental)

-- Schema-only creation: run once to initialize table if it does not exist
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`03_gold`.fact_green_taxi_trip (
  trip_key BIGINT,
  vendor_id INT,
  pickup_datetime TIMESTAMP,
  dropoff_datetime TIMESTAMP,
  pickup_date_key INT,
  dropoff_date_key INT,
  pickup_time_key INT,
  dropoff_time_key INT,
  pickup_taxi_zone_key INT,
  dropoff_taxi_zone_key INT,
  pickup_weather_hour_key BIGINT,
  trip_count BIGINT,
  passenger_count INT,
  trip_distance DOUBLE,
  trip_duration_minutes DOUBLE,
  trip_average_speed_mph DOUBLE,
  total_amount_per_mile DOUBLE,
  fare_amount DOUBLE,
  extra DOUBLE,
  mta_tax DOUBLE,
  tip_amount DOUBLE,
  tolls_amount DOUBLE,
  improvement_surcharge DOUBLE,
  congestion_surcharge DOUBLE,
  cbd_congestion_fee DOUBLE,
  total_amount DOUBLE,
  payment_type INT,
  payment_type_description STRING,
  trip_type INT,
  rate_code_id INT,
  store_and_fwd_flag STRING,
  dq_zero_trip_distance BOOLEAN,
  dq_extreme_trip_distance BOOLEAN,
  dq_negative_trip_distance BOOLEAN,
  dq_out_of_range_datetime BOOLEAN,
  dq_invalid_trip_duration BOOLEAN,
  dq_missing_weather_coverage BOOLEAN,
  source_system STRING,
  source_file STRING,
  batch_id STRING
)
USING DELTA;

-- COMMAND ----------

-- Idempotent upsert: insert new trips and update existing ones based on xxhash64 trip_key
MERGE INTO `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS target
USING (
  SELECT
    xxhash64(
        g.VendorID,
        g.lpep_pickup_datetime,
        g.lpep_dropoff_datetime,
        g.store_and_fwd_flag,
        g.RatecodeID,
        g.PULocationID,
        g.DOLocationID,
        g.passenger_count,
        g.trip_distance,
        g.trip_duration_minutes,
        g.fare_amount,
        g.extra,
        g.mta_tax,
        g.tip_amount,
        g.tolls_amount,
        g.improvement_surcharge,
        g.total_amount,
        g.payment_type,
        g.trip_type,
        g.congestion_surcharge,
        g.cbd_congestion_fee,
        g.source_file
    ) AS trip_key,

    g.VendorID AS vendor_id,
    g.lpep_pickup_datetime AS pickup_datetime,
    g.lpep_dropoff_datetime AS dropoff_datetime,

    CAST(DATE_FORMAT(TO_DATE(g.lpep_pickup_datetime), 'yyyyMMdd') AS INT) AS pickup_date_key,
    CAST(DATE_FORMAT(TO_DATE(g.lpep_dropoff_datetime), 'yyyyMMdd') AS INT) AS dropoff_date_key,

    COALESCE(HOUR(g.lpep_pickup_datetime) + 1, 0) AS pickup_time_key,
    COALESCE(HOUR(g.lpep_dropoff_datetime) + 1, 0) AS dropoff_time_key,

    CAST(g.PULocationID AS INT) AS pickup_taxi_zone_key,
    CAST(g.DOLocationID AS INT) AS dropoff_taxi_zone_key,
    COALESCE(w.weather_hour_key, CAST(0 AS BIGINT)) AS pickup_weather_hour_key,

    CAST(1 AS BIGINT) AS trip_count,
    g.passenger_count,
    g.trip_distance,
    g.trip_duration_minutes,
    CASE
        WHEN g.trip_duration_minutes > 0
        THEN g.trip_distance / (g.trip_duration_minutes / 60.0)
    END AS trip_average_speed_mph,
    CASE
        WHEN g.trip_distance > 0
        THEN g.total_amount / g.trip_distance
    END AS total_amount_per_mile,

    g.fare_amount,
    g.extra,
    g.mta_tax,
    g.tip_amount,
    g.tolls_amount,
    g.improvement_surcharge,
    g.congestion_surcharge,
    g.cbd_congestion_fee,
    g.total_amount,

    g.payment_type,
    g.payment_type_description,
    g.trip_type,
    g.RatecodeID AS rate_code_id,
    g.store_and_fwd_flag,

    g.dq_zero_trip_distance,
    g.dq_extreme_trip_distance,
    g.dq_negative_trip_distance,
    g.dq_out_of_range_datetime,
    g.dq_invalid_trip_duration,
    w.weather_hour_key IS NULL AS dq_missing_weather_coverage,

    g.source_system,
    g.source_file,
    g.batch_id

  FROM `ftw-week-08`.`02_silver`.green_taxi AS g
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w
      ON w.weather_hour_key = CAST(
          DATE_FORMAT(g.pickup_hour, 'yyyyMMddHH') AS BIGINT
      )
     AND w.weather_hour_key != 0
) AS source
ON target.trip_key = source.trip_key
WHEN MATCHED THEN
  UPDATE SET
    target.pickup_weather_hour_key = source.pickup_weather_hour_key,
    target.dq_missing_weather_coverage = source.dq_missing_weather_coverage
WHEN NOT MATCHED THEN
  INSERT (
    trip_key, vendor_id, pickup_datetime, dropoff_datetime,
    pickup_date_key, dropoff_date_key, pickup_time_key, dropoff_time_key,
    pickup_taxi_zone_key, dropoff_taxi_zone_key, pickup_weather_hour_key,
    trip_count, passenger_count, trip_distance, trip_duration_minutes,
    trip_average_speed_mph, total_amount_per_mile,
    fare_amount, extra, mta_tax, tip_amount, tolls_amount,
    improvement_surcharge, congestion_surcharge, cbd_congestion_fee, total_amount,
    payment_type, payment_type_description, trip_type, rate_code_id, store_and_fwd_flag,
    dq_zero_trip_distance, dq_extreme_trip_distance, dq_negative_trip_distance,
    dq_out_of_range_datetime, dq_invalid_trip_duration, dq_missing_weather_coverage,
    source_system, source_file, batch_id
  )
  VALUES (
    source.trip_key, source.vendor_id, source.pickup_datetime, source.dropoff_datetime,
    source.pickup_date_key, source.dropoff_date_key, source.pickup_time_key, source.dropoff_time_key,
    source.pickup_taxi_zone_key, source.dropoff_taxi_zone_key, source.pickup_weather_hour_key,
    source.trip_count, source.passenger_count, source.trip_distance, source.trip_duration_minutes,
    source.trip_average_speed_mph, source.total_amount_per_mile,
    source.fare_amount, source.extra, source.mta_tax, source.tip_amount, source.tolls_amount,
    source.improvement_surcharge, source.congestion_surcharge, source.cbd_congestion_fee, source.total_amount,
    source.payment_type, source.payment_type_description, source.trip_type, source.rate_code_id, source.store_and_fwd_flag,
    source.dq_zero_trip_distance, source.dq_extreme_trip_distance, source.dq_negative_trip_distance,
    source.dq_out_of_range_datetime, source.dq_invalid_trip_duration, source.dq_missing_weather_coverage,
    source.source_system, source.source_file, source.batch_id
  );
