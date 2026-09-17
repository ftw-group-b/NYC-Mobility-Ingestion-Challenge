-- Databricks notebook source
-- 6. Audit Details
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_problem_areas AS
WITH audit_rows AS (
  SELECT
    f.*,
    z.taxi_zone_key IS NULL AS dq_unmapped_pickup_zone,
    f.trip_key IS NULL AS dq_null_trip_key,
    (
      f.source_system IS NULL
      OR f.source_file IS NULL
      OR f.batch_id IS NULL
    ) AS dq_missing_lineage,
    COUNT(*) OVER (
      PARTITION BY f.trip_key
    ) > 1 AND f.trip_key IS NOT NULL AS dq_duplicate_trip_key
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z
    ON f.pickup_taxi_zone_key = z.taxi_zone_key
)
SELECT
  trip_key,
  pickup_datetime,
  dropoff_datetime,
  pickup_taxi_zone_key,
  dropoff_taxi_zone_key,
  dq_zero_trip_distance,
  dq_extreme_trip_distance,
  dq_negative_trip_distance,
  dq_invalid_trip_duration,
  dq_missing_weather_coverage,
  dq_unmapped_pickup_zone,
  dq_null_trip_key,
  dq_missing_lineage,
  dq_duplicate_trip_key,
  source_file,
  batch_id
FROM audit_rows
WHERE dq_zero_trip_distance
   OR dq_extreme_trip_distance
   OR dq_negative_trip_distance
   OR dq_invalid_trip_duration
   OR dq_missing_weather_coverage
   OR dq_unmapped_pickup_zone
   OR dq_null_trip_key
   OR dq_missing_lineage
   OR dq_duplicate_trip_key;
