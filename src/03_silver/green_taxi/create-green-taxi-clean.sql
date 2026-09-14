CREATE OR REPLACE TABLE `ftw-week-08`.`02_silver`.`green_taxi`
USING DELTA
AS
SELECT
  -- Primary identifiers
  VendorID,
  
  -- Timestamps (keep as-is, flagged separately)
  lpep_pickup_datetime,
  lpep_dropoff_datetime,
  
  -- Trip identifiers and codes
  store_and_fwd_flag,
  RatecodeID,
  PULocationID,
  DOLocationID,
  passenger_count,
  
  -- Trip distance: NULL if > 1000, otherwise keep original value
  CASE 
    WHEN trip_distance > 1000 THEN NULL
    ELSE trip_distance
  END AS trip_distance,
  
  -- Financial columns (keep all values including negatives)
  fare_amount,
  extra,
  mta_tax,
  tip_amount,
  tolls_amount,
  improvement_surcharge,
  total_amount,
  
  -- Payment and trip type
  payment_type,
  trip_type,
  
  -- Surcharges
  congestion_surcharge,
  cbd_congestion_fee,
  
  -- Data Quality Flags
  CASE 
    WHEN trip_distance > 1000 THEN TRUE
    ELSE FALSE
  END AS dq_invalid_trip_distance,
  
  CASE
    WHEN lpep_pickup_datetime < TIMESTAMP '2026-03-01 00:00:00'
      OR lpep_pickup_datetime >= TIMESTAMP '2026-06-01 00:00:00'
      OR lpep_dropoff_datetime < TIMESTAMP '2026-03-01 00:00:00'
      OR lpep_dropoff_datetime >= TIMESTAMP '2026-06-01 00:00:00'
    THEN TRUE
    ELSE FALSE
  END AS dq_out_of_range_datetime,
  
  -- Provenance columns
  source_system,
  source_file,
  batch_id,
  ingested_at
  
FROM `ftw-week-08`.`01_bronze`.`green_taxi`
-- Note: _rescued_data and ehail_fee are dropped (100% NULL)
