-- Databricks notebook source
-- 2. Executive Overview
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_overview AS
WITH row_status AS (
  SELECT
    f.*,
    ROW_NUMBER() OVER (
      PARTITION BY f.trip_key
      ORDER BY f.trip_key
    ) AS trip_key_row_number,
    (
      d_pickup.date_key IS NULL
      OR d_dropoff.date_key IS NULL
      OR t_pickup.time_key IS NULL
      OR t_dropoff.time_key IS NULL
      OR z_pickup.taxi_zone_key IS NULL
      OR z_dropoff.taxi_zone_key IS NULL
      OR w.weather_hour_key IS NULL
    ) AS has_orphaned_fk
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_pickup ON f.pickup_date_key = d_pickup.date_key
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_dropoff ON f.dropoff_date_key = d_dropoff.date_key
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_pickup ON f.pickup_time_key = t_pickup.time_key
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_dropoff ON f.dropoff_time_key = t_dropoff.time_key
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_pickup ON f.pickup_taxi_zone_key = z_pickup.taxi_zone_key
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_dropoff ON f.dropoff_taxi_zone_key = z_dropoff.taxi_zone_key
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w ON f.pickup_weather_hour_key = w.weather_hour_key
),
summary AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(
      dq_zero_trip_distance
      OR dq_extreme_trip_distance
      OR dq_negative_trip_distance
      OR dq_invalid_trip_duration
      OR dq_missing_weather_coverage
      OR source_system IS NULL
      OR source_file IS NULL
      OR batch_id IS NULL
      OR trip_key IS NULL
      OR trip_key_row_number > 1
      OR has_orphaned_fk
    ) AS rows_with_any_dq_flag,
    COUNT_IF(has_orphaned_fk) AS rows_with_orphaned_fk,
    COUNT_IF(dq_out_of_range_datetime) AS outside_analysis_window_rows,
    COUNT_IF(trip_key IS NULL) AS null_trip_key_count
  FROM row_status
)
SELECT
  CURRENT_TIMESTAMP() AS last_checked_at,
  total_rows,
  rows_with_any_dq_flag,
  rows_with_orphaned_fk,
  outside_analysis_window_rows,
  total_rows - rows_with_any_dq_flag AS clean_rows,
  CAST(
    100.0 * (total_rows - rows_with_any_dq_flag) / NULLIF(total_rows, 0)
    AS DECIMAL(7, 3)
  ) AS clean_row_pct,
  null_trip_key_count
FROM summary;
