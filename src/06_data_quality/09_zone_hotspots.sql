-- Databricks notebook source
-- 9. Zone Hotspots
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_zone_hotspots AS
SELECT
  f.pickup_taxi_zone_key,
  COALESCE(z.zone_name, 'Unmapped / Unknown Zone') AS zone_name,
  COALESCE(z.borough, 'Unknown Borough') AS borough,
  COUNT(*) AS total_pickups,
  COUNT_IF(
    f.dq_zero_trip_distance
    OR f.dq_extreme_trip_distance
    OR f.dq_negative_trip_distance
    OR f.dq_invalid_trip_duration
    OR f.dq_missing_weather_coverage
  ) AS flagged_pickups,
  COUNT_IF(f.dq_out_of_range_datetime) AS outside_analysis_window_pickups,
  ROUND(
    100.0 * COUNT_IF(
      f.dq_zero_trip_distance
      OR f.dq_extreme_trip_distance
      OR f.dq_negative_trip_distance
      OR f.dq_invalid_trip_duration
      OR f.dq_missing_weather_coverage
    ) / NULLIF(COUNT(*), 0),
    3
  ) AS flagged_pct
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z
  ON f.pickup_taxi_zone_key = z.taxi_zone_key
GROUP BY f.pickup_taxi_zone_key, z.zone_name, z.borough
ORDER BY flagged_pickups DESC;
