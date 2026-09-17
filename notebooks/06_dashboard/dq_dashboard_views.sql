-- Databricks notebook source
-- Name: NYC Mobility Data Quality Dashboard Views
-- Purpose: Publish a current DQ snapshot based on the data quality flagsfrom the Gold fact table.
-- Note: These flags represent a single Gold build and do not capture
--       repeated validation runs. This notebook does not maintain
--       DQ run history or track validation results across runs.

-- One-row executive snapshot for the DQ dashboard's top tile.
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_overview AS
WITH flagged AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(
      dq_zero_trip_distance OR dq_extreme_trip_distance
      OR dq_negative_trip_distance OR dq_out_of_range_datetime
      OR dq_invalid_trip_duration OR dq_missing_weather_coverage
    ) AS rows_with_any_flag,
    COUNT(DISTINCT trip_key) AS unique_trip_keys
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
)
SELECT
  CURRENT_TIMESTAMP() AS last_checked_at,
  total_rows,
  rows_with_any_flag,
  total_rows - rows_with_any_flag AS clean_rows,
  CAST(100.0 * (total_rows - rows_with_any_flag) / NULLIF(total_rows, 0) AS DECIMAL(7, 3))
    AS clean_row_pct,
  total_rows - unique_trip_keys AS duplicate_trip_key_count
FROM flagged;

-- Per-check counts, each tagged with the quality dimension it belongs to.
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_check_scores AS
WITH totals AS (
  SELECT COUNT(*) AS total_rows
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
)
SELECT
  check_name,
  quality_dimension,
  flagged_rows,
  t.total_rows,
  ROUND(100.0 * flagged_rows / t.total_rows, 3) AS flagged_pct
FROM (
  SELECT 'Zero trip distance' AS check_name, 'VALIDITY' AS quality_dimension,
         COUNT_IF(dq_zero_trip_distance) AS flagged_rows
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip

  UNION ALL
  SELECT 'Extreme trip distance', 'VALIDITY', COUNT_IF(dq_extreme_trip_distance)
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip

  UNION ALL
  SELECT 'Negative trip distance', 'VALIDITY', COUNT_IF(dq_negative_trip_distance)
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip

  UNION ALL
  SELECT 'Out-of-range pickup/dropoff datetime', 'VALIDITY', COUNT_IF(dq_out_of_range_datetime)
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip

  UNION ALL
  SELECT 'Invalid trip duration', 'VALIDITY', COUNT_IF(dq_invalid_trip_duration)
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip

  UNION ALL
  SELECT 'Missing weather coverage', 'COMPLETENESS', COUNT_IF(dq_missing_weather_coverage)
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip

  UNION ALL
  SELECT 'Duplicate trip key', 'UNIQUENESS', COUNT(*) - COUNT(DISTINCT trip_key)
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
) AS checks
CROSS JOIN totals AS t
ORDER BY flagged_rows DESC;

-- Aggregate check scores up to the dimension level.
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_dimension_scores AS
SELECT
  quality_dimension,
  SUM(flagged_rows) AS flagged_rows,
  MAX(total_rows) AS total_rows,
  ROUND(100.0 * SUM(flagged_rows) / MAX(total_rows), 3) AS flagged_pct,
  COUNT(*) AS checks_in_dimension
FROM `ftw-week-08`.`03_gold`.dq_dashboard_check_scores
GROUP BY quality_dimension;

-- Left join to a six-dimension catalog so an unmeasured dimension shows as
-- NOT_MEASURED instead of silently disappearing from the dashboard.
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_canonical_dimensions AS
WITH dimension_catalog AS (
  SELECT dimension_order, dimension_key, dimension_label
  FROM VALUES
    (1, 'COMPLETENESS', 'Completeness'),
    (2, 'VALIDITY', 'Validity'),
    (3, 'UNIQUENESS', 'Uniqueness'),
    (4, 'CONSISTENCY', 'Consistency'),
    (5, 'ACCURACY', 'Accuracy'),
    (6, 'TIMELINESS_VOLUME', 'Timeliness / Volume')
    AS catalog(dimension_order, dimension_key, dimension_label)
)
SELECT
  catalog.dimension_order,
  catalog.dimension_key,
  catalog.dimension_label,
  scores.flagged_rows,
  scores.total_rows,
  scores.flagged_pct,
  scores.checks_in_dimension,
  CASE WHEN scores.quality_dimension IS NULL THEN 'NOT_MEASURED' ELSE 'MEASURED' END
    AS measurement_status,
  CASE
    WHEN catalog.dimension_key = 'ACCURACY'
      THEN 'N/A - no external ground truth for reconciliation'
    WHEN catalog.dimension_key = 'CONSISTENCY'
      THEN 'See dq_dashboard_referential_integrity for FK checks'
    WHEN catalog.dimension_key = 'TIMELINESS_VOLUME'
      THEN 'See dq_dashboard_row_reconciliation for Silver-to-Gold row counts'
    ELSE 'Directly measured from fact_green_taxi_trip dq_* flags'
  END AS measurement_note
FROM dimension_catalog AS catalog
LEFT JOIN `ftw-week-08`.`03_gold`.dq_dashboard_dimension_scores AS scores
  ON catalog.dimension_key = scores.quality_dimension;

-- Individual flagged rows, for audit/drill-down. Unfiltered by design.
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_problem_areas AS
SELECT
  trip_key,
  pickup_datetime,
  dropoff_datetime,
  pickup_taxi_zone_key,
  dropoff_taxi_zone_key,
  dq_zero_trip_distance,
  dq_extreme_trip_distance,
  dq_negative_trip_distance,
  dq_out_of_range_datetime,
  dq_invalid_trip_duration,
  dq_missing_weather_coverage,
  source_file,
  batch_id
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
WHERE dq_zero_trip_distance OR dq_extreme_trip_distance
   OR dq_negative_trip_distance OR dq_out_of_range_datetime
   OR dq_invalid_trip_duration OR dq_missing_weather_coverage;

-- Fact-to-dimension referential integrity (Consistency dimension).
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_referential_integrity AS
SELECT
  SUM(CASE WHEN d_pickup.date_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_date_keys,
  SUM(CASE WHEN d_dropoff.date_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_date_keys,
  SUM(CASE WHEN t_pickup.time_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_time_keys,
  SUM(CASE WHEN t_dropoff.time_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_time_keys,
  SUM(CASE WHEN z_pickup.taxi_zone_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_zone_keys,
  SUM(CASE WHEN z_dropoff.taxi_zone_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_zone_keys,
  SUM(CASE WHEN w.weather_hour_key IS NULL THEN 1 ELSE 0 END) AS missing_weather_keys,
  COUNT(*) AS total_rows
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_pickup ON f.pickup_date_key = d_pickup.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_dropoff ON f.dropoff_date_key = d_dropoff.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_pickup ON f.pickup_time_key = t_pickup.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_dropoff ON f.dropoff_time_key = t_dropoff.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_pickup ON f.pickup_taxi_zone_key = z_pickup.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_dropoff ON f.dropoff_taxi_zone_key = z_dropoff.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w ON f.pickup_weather_hour_key = w.weather_hour_key;

-- Silver-to-Gold row reconciliation (Timeliness/Volume proxy).
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_row_reconciliation AS
WITH silver_summary AS (
  SELECT COUNT(*) AS silver_row_count
  FROM `ftw-week-08`.`02_silver`.green_taxi
),
gold_summary AS (
  SELECT COUNT(*) AS gold_row_count
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
)
SELECT
  s.silver_row_count,
  g.gold_row_count,
  g.gold_row_count - s.silver_row_count AS row_count_difference
FROM silver_summary AS s
CROSS JOIN gold_summary AS g;

-- Zone-level concentration of flagged rows, for locating where DQ issues cluster.
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_zone_hotspots AS
SELECT
  z.zone_name,
  z.borough,
  COUNT(*) AS total_pickups,
  COUNT_IF(
    f.dq_zero_trip_distance OR f.dq_extreme_trip_distance
    OR f.dq_negative_trip_distance OR f.dq_out_of_range_datetime
    OR f.dq_invalid_trip_duration OR f.dq_missing_weather_coverage
  ) AS flagged_pickups,
  ROUND(
    100.0 * COUNT_IF(
      f.dq_zero_trip_distance OR f.dq_extreme_trip_distance
      OR f.dq_negative_trip_distance OR f.dq_out_of_range_datetime
      OR f.dq_invalid_trip_duration OR f.dq_missing_weather_coverage
    ) / COUNT(*),
    3
  ) AS flagged_pct
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z
  ON f.pickup_taxi_zone_key = z.taxi_zone_key
GROUP BY z.zone_name, z.borough
ORDER BY flagged_pickups DESC;