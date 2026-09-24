-- Databricks notebook source
-- Modular source: Silver Green Taxi table (incremental)

-- Schema-only creation: run once to initialize table if it does not exist
-- WHERE 1=0 creates the column structure without inserting any data
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`02_silver`.`green_taxi`
USING DELTA
AS
SELECT
  VendorID,

  lpep_pickup_datetime,
  CAST(
    date_trunc('hour', lpep_pickup_datetime)
    AS TIMESTAMP_NTZ
  ) AS pickup_hour,

  lpep_dropoff_datetime,
  CAST(
    date_trunc('hour', lpep_dropoff_datetime)
    AS TIMESTAMP_NTZ
  ) AS dropoff_hour,

  CASE
    WHEN lpep_pickup_datetime IS NOT NULL
      AND lpep_dropoff_datetime IS NOT NULL
      AND lpep_dropoff_datetime >= lpep_pickup_datetime
    THEN TIMESTAMPDIFF(
      MICROSECOND,
      lpep_pickup_datetime,
      lpep_dropoff_datetime
    ) / 60000000.0
    ELSE NULL
  END AS trip_duration_minutes,

  store_and_fwd_flag,
  RatecodeID,
  PULocationID,
  DOLocationID,
  passenger_count,

  CASE
    WHEN trip_distance > 1000 THEN NULL
    WHEN trip_distance < 0 THEN NULL
    ELSE trip_distance
  END AS trip_distance,

  fare_amount,
  extra,
  mta_tax,
  tip_amount,
  tolls_amount,
  improvement_surcharge,
  total_amount,

  payment_type,
  CASE
    WHEN payment_type IS NULL THEN NULL
    WHEN payment_type = 0 THEN 'Flex Fare trip'
    WHEN payment_type = 1 THEN 'Credit card'
    WHEN payment_type = 2 THEN 'Cash'
    WHEN payment_type = 3 THEN 'No charge'
    WHEN payment_type = 4 THEN 'Dispute'
    WHEN payment_type = 5 THEN 'Unknown'
    WHEN payment_type = 6 THEN 'Voided trip'
    ELSE 'Invalid/unmapped'
  END AS payment_type_description,

  trip_type,

  congestion_surcharge,
  cbd_congestion_fee,

  CASE WHEN trip_distance = 0 THEN TRUE ELSE FALSE END AS dq_zero_trip_distance,
  CASE WHEN trip_distance > 1000 THEN TRUE ELSE FALSE END AS dq_extreme_trip_distance,
  CASE WHEN trip_distance < 0 THEN TRUE ELSE FALSE END AS dq_negative_trip_distance,

  CASE
    WHEN lpep_pickup_datetime < TIMESTAMP_NTZ '2026-03-01 00:00:00'
      OR lpep_pickup_datetime >= TIMESTAMP_NTZ '2026-06-01 00:00:00'
      OR lpep_dropoff_datetime < TIMESTAMP_NTZ '2026-03-01 00:00:00'
      OR lpep_dropoff_datetime >= TIMESTAMP_NTZ '2026-06-01 00:00:00'
    THEN TRUE
    ELSE FALSE
  END AS dq_out_of_range_datetime,

  CASE
    WHEN lpep_pickup_datetime IS NOT NULL
      AND lpep_dropoff_datetime IS NOT NULL
      AND lpep_dropoff_datetime < lpep_pickup_datetime
    THEN TRUE
    ELSE FALSE
  END AS dq_invalid_trip_duration,

  source_system,
  source_file,
  batch_id,
  ingested_at

FROM `ftw-week-08`.`01_bronze`.`green_taxi`
WHERE 1 = 0;

-- COMMAND ----------

-- Incremental execution: appends only files not already present in Silver
INSERT INTO `ftw-week-08`.`02_silver`.`green_taxi`
SELECT
  VendorID,

  lpep_pickup_datetime,
  CAST(
    date_trunc('hour', lpep_pickup_datetime)
    AS TIMESTAMP_NTZ
  ) AS pickup_hour,

  lpep_dropoff_datetime,
  CAST(
    date_trunc('hour', lpep_dropoff_datetime)
    AS TIMESTAMP_NTZ
  ) AS dropoff_hour,

  CASE
    WHEN lpep_pickup_datetime IS NOT NULL
      AND lpep_dropoff_datetime IS NOT NULL
      AND lpep_dropoff_datetime >= lpep_pickup_datetime
    THEN TIMESTAMPDIFF(
      MICROSECOND,
      lpep_pickup_datetime,
      lpep_dropoff_datetime
    ) / 60000000.0
    ELSE NULL
  END AS trip_duration_minutes,

  store_and_fwd_flag,
  RatecodeID,
  PULocationID,
  DOLocationID,
  passenger_count,

  CASE
    WHEN trip_distance > 1000 THEN NULL
    WHEN trip_distance < 0 THEN NULL
    ELSE trip_distance
  END AS trip_distance,

  fare_amount,
  extra,
  mta_tax,
  tip_amount,
  tolls_amount,
  improvement_surcharge,
  total_amount,

  payment_type,
  CASE
    WHEN payment_type IS NULL THEN NULL
    WHEN payment_type = 0 THEN 'Flex Fare trip'
    WHEN payment_type = 1 THEN 'Credit card'
    WHEN payment_type = 2 THEN 'Cash'
    WHEN payment_type = 3 THEN 'No charge'
    WHEN payment_type = 4 THEN 'Dispute'
    WHEN payment_type = 5 THEN 'Unknown'
    WHEN payment_type = 6 THEN 'Voided trip'
    ELSE 'Invalid/unmapped'
  END AS payment_type_description,

  trip_type,

  congestion_surcharge,
  cbd_congestion_fee,

  CASE WHEN trip_distance = 0 THEN TRUE ELSE FALSE END AS dq_zero_trip_distance,
  CASE WHEN trip_distance > 1000 THEN TRUE ELSE FALSE END AS dq_extreme_trip_distance,
  CASE WHEN trip_distance < 0 THEN TRUE ELSE FALSE END AS dq_negative_trip_distance,

  CASE
    WHEN lpep_pickup_datetime < TIMESTAMP_NTZ '2026-03-01 00:00:00'
      OR lpep_pickup_datetime >= TIMESTAMP_NTZ '2026-06-01 00:00:00'
      OR lpep_dropoff_datetime < TIMESTAMP_NTZ '2026-03-01 00:00:00'
      OR lpep_dropoff_datetime >= TIMESTAMP_NTZ '2026-06-01 00:00:00'
    THEN TRUE
    ELSE FALSE
  END AS dq_out_of_range_datetime,

  CASE
    WHEN lpep_pickup_datetime IS NOT NULL
      AND lpep_dropoff_datetime IS NOT NULL
      AND lpep_dropoff_datetime < lpep_pickup_datetime
    THEN TRUE
    ELSE FALSE
  END AS dq_invalid_trip_duration,

  source_system,
  source_file,
  batch_id,
  ingested_at

FROM `ftw-week-08`.`01_bronze`.`green_taxi` AS b
WHERE b.source_file IN (
    SELECT source_identifier
    FROM `ftw-week-08`.`01_bronze`.`ingestion_log`
    WHERE source_name = 'green_taxi'
      AND status = 'SUCCESS'
)
AND NOT EXISTS (
    SELECT 1
    FROM `ftw-week-08`.`02_silver`.`green_taxi` AS s
    WHERE s.source_file = b.source_file
);
