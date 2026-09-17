-- Databricks notebook source
-- Modular source: Silver Green Taxi table

CREATE OR REPLACE TABLE `ftw-week-08`.`02_silver`.`green_taxi`
USING DELTA
AS
SELECT
  -- Primary identifier
  VendorID,

  -- Timestamps
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

  -- Trip duration: calculate only when timestamps are usable
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

  -- Trip identifiers and codes
  store_and_fwd_flag,
  RatecodeID,
  PULocationID,
  DOLocationID,
  passenger_count,

  -- Trip distance: NULL if negative or >1000
  -- Zero and valid values are retained
  CASE
    WHEN trip_distance > 1000 THEN NULL
    WHEN trip_distance < 0 THEN NULL
    ELSE trip_distance
  END AS trip_distance,

  -- Financial columns
  fare_amount,
  extra,
  mta_tax,
  tip_amount,
  tolls_amount,
  improvement_surcharge,
  total_amount,

  -- Payment and trip type
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

  -- Surcharges
  congestion_surcharge,
  cbd_congestion_fee,

  -- Data quality flags
  CASE
    WHEN trip_distance = 0 THEN TRUE
    ELSE FALSE
  END AS dq_zero_trip_distance,

  CASE
    WHEN trip_distance > 1000 THEN TRUE
    ELSE FALSE
  END AS dq_extreme_trip_distance,

  CASE
    WHEN trip_distance < 0 THEN TRUE
    ELSE FALSE
  END AS dq_negative_trip_distance,

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

  -- Provenance
  source_system,
  source_file,
  batch_id,
  ingested_at

FROM `ftw-week-08`.`01_bronze`.`green_taxi`;
