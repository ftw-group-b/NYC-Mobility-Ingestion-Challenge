-- Databricks notebook source
-- 1. Executive Overview
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_overview AS
WITH fact_summary AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(
      dq_zero_trip_distance
      OR dq_extreme_trip_distance
      OR dq_negative_trip_distance
      OR dq_invalid_trip_duration
      OR dq_missing_weather_coverage
      OR trip_key IS NULL
    ) AS base_flagged_rows,
    COUNT_IF(dq_out_of_range_datetime) AS outside_analysis_window_rows,
    COUNT_IF(trip_key IS NULL) AS null_trip_key_count
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
),
dup_summary AS (
  SELECT COALESCE(SUM(key_count - 1), 0) AS duplicate_non_null_trip_key_count
  FROM (
    SELECT COUNT(*) AS key_count
    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
    WHERE trip_key IS NOT NULL
    GROUP BY trip_key
    HAVING COUNT(*) > 1
  )
),
ref_integrity AS (
  SELECT (missing_pickup_date_keys + missing_dropoff_date_keys + missing_pickup_time_keys + 
          missing_dropoff_time_keys + missing_pickup_zone_keys + missing_dropoff_zone_keys + 
          missing_weather_keys) AS rows_with_orphaned_fk
  FROM `ftw-week-08`.`03_gold`.dq_dashboard_referential_integrity
)
SELECT
  CURRENT_TIMESTAMP() AS last_checked_at,
  f.total_rows,
  LEAST(f.total_rows, f.base_flagged_rows + d.duplicate_non_null_trip_key_count + r.rows_with_orphaned_fk) AS rows_with_any_dq_flag,
  r.rows_with_orphaned_fk,
  f.outside_analysis_window_rows,
  f.total_rows - LEAST(f.total_rows, f.base_flagged_rows + d.duplicate_non_null_trip_key_count + r.rows_with_orphaned_fk) AS clean_rows,
  CAST(100.0 * (f.total_rows - LEAST(f.total_rows, f.base_flagged_rows + d.duplicate_non_null_trip_key_count + r.rows_with_orphaned_fk)) / NULLIF(f.total_rows, 0) AS DECIMAL(7, 3)) AS clean_row_pct,
  d.duplicate_non_null_trip_key_count,
  f.null_trip_key_count
FROM fact_summary f
CROSS JOIN dup_summary d
CROSS JOIN ref_integrity r;

-- 2. Check Scores
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_check_scores AS
WITH aggregated_checks AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(dq_zero_trip_distance) AS zero_dist,
    COUNT_IF(dq_extreme_trip_distance) AS extreme_dist,
    COUNT_IF(dq_negative_trip_distance) AS neg_dist,
    COUNT_IF(dq_invalid_trip_duration) AS invalid_dur,
    COUNT_IF(dq_missing_weather_coverage) AS missing_weather,
    COUNT_IF(pickup_taxi_zone_key IN (0, 264, 265) OR pickup_taxi_zone_key IS NULL) AS unmapped_zone,
    COUNT_IF(trip_key IS NULL) AS null_key
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
),
dup_check AS (
  SELECT COALESCE(SUM(key_count - 1), 0) AS dup_key
  FROM (
    SELECT COUNT(*) AS key_count
    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
    WHERE trip_key IS NOT NULL
    GROUP BY trip_key HAVING COUNT(*) > 1
  )
)
SELECT check_name, quality_dimension, flagged_rows, total_rows, ROUND(100.0 * flagged_rows / NULLIF(total_rows, 0), 3) AS flagged_pct
FROM (
  SELECT 'Zero trip distance' AS check_name, 'VALIDITY' AS quality_dimension, zero_dist AS flagged_rows, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Extreme trip distance', 'VALIDITY', extreme_dist, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Negative trip distance', 'VALIDITY', neg_dist, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Invalid trip duration', 'VALIDITY', invalid_dur, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Missing weather coverage', 'COMPLETENESS', missing_weather, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Unknown / unmapped pickup zone', 'COMPLETENESS', unmapped_zone, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Null trip key', 'UNIQUENESS', null_key, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Duplicate trip key', 'UNIQUENESS', d.dup_key, a.total_rows FROM aggregated_checks a CROSS JOIN dup_check d
)
ORDER BY flagged_rows DESC;

-- 3. Dimension Scores
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_dimension_scores AS
WITH fact_summary AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(
      dq_zero_trip_distance
      OR dq_extreme_trip_distance
      OR dq_negative_trip_distance
      OR dq_invalid_trip_duration
    ) AS validity_flagged_rows,
    COUNT_IF(
      dq_missing_weather_coverage
      OR pickup_taxi_zone_key IN (0, 264, 265)
      OR pickup_taxi_zone_key IS NULL
    ) AS completeness_flagged_rows,
    COUNT_IF(trip_key IS NULL) AS null_trip_key_rows
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
),
duplicate_summary AS (
  SELECT
    COALESCE(SUM(key_count - 1), 0) AS duplicate_trip_key_rows
  FROM (
    SELECT COUNT(*) AS key_count
    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
    WHERE trip_key IS NOT NULL
    GROUP BY trip_key
    HAVING COUNT(*) > 1
  )
),
dimension_results AS (
  SELECT
    'VALIDITY' AS quality_dimension,
    validity_flagged_rows AS flagged_rows,
    total_rows,
    4 AS checks_in_dimension
  FROM fact_summary
  UNION ALL
  SELECT
    'COMPLETENESS',
    completeness_flagged_rows,
    total_rows,
    2 AS checks_in_dimension
  FROM fact_summary
  UNION ALL
  SELECT
    'UNIQUENESS',
    null_trip_key_rows + duplicate_trip_key_rows,
    total_rows,
    2 AS checks_in_dimension
  FROM fact_summary
  CROSS JOIN duplicate_summary
)
SELECT
  quality_dimension,
  flagged_rows,
  total_rows,
  ROUND(
    100.0 * flagged_rows / NULLIF(total_rows, 0),
    3
  ) AS flagged_pct,
  checks_in_dimension
FROM dimension_results;

-- 4. Canonical Dimensions Catalog
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
  COALESCE(scores.flagged_rows, 0) AS flagged_rows,
  COALESCE(scores.total_rows, (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip)) AS total_rows,
  COALESCE(scores.flagged_pct, 0.0) AS flagged_pct,
  COALESCE(scores.checks_in_dimension, 0) AS checks_in_dimension,
  CASE
    WHEN scores.quality_dimension IS NOT NULL
      THEN 'MEASURED'
    WHEN catalog.dimension_key IN ('CONSISTENCY', 'TIMELINESS_VOLUME')
      THEN 'MEASURED_SEPARATELY'
    ELSE 'NOT_MEASURED'
  END AS measurement_status,
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

-- 5. Audit Details
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
  dq_invalid_trip_duration,
  dq_missing_weather_coverage,
  source_file,
  batch_id
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
WHERE dq_zero_trip_distance
   OR dq_extreme_trip_distance
   OR dq_negative_trip_distance
   OR dq_invalid_trip_duration
   OR dq_missing_weather_coverage;

-- 6. Outside Analysis Window
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_outside_analysis_window AS
SELECT
  trip_key,
  pickup_datetime,
  dropoff_datetime,
  source_file,
  batch_id
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
WHERE dq_out_of_range_datetime = TRUE;

-- 7. Referential Integrity
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_referential_integrity AS
SELECT
  SUM(CASE WHEN d_pickup.date_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_date_keys,
  SUM(CASE WHEN d_dropoff.date_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_date_keys,
  SUM(CASE WHEN t_pickup.time_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_time_keys,
  SUM(CASE WHEN t_dropoff.time_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_time_keys,
  SUM(CASE WHEN z_pickup.taxi_zone_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_zone_keys,
  SUM(CASE WHEN z_dropoff.taxi_zone_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_zone_keys,
  SUM(CASE WHEN w.weather_hour_key IS NULL THEN 1 ELSE 0 END) AS missing_weather_keys,
  COUNT(*) AS joined_rows,
  (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip) AS fact_rows,
  COUNT(*) - (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip) AS join_row_difference
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_pickup ON f.pickup_date_key = d_pickup.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_dropoff ON f.dropoff_date_key = d_dropoff.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_pickup ON f.pickup_time_key = t_pickup.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_dropoff ON f.dropoff_time_key = t_dropoff.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_pickup ON f.pickup_taxi_zone_key = z_pickup.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_dropoff ON f.dropoff_taxi_zone_key = z_dropoff.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w ON f.pickup_weather_hour_key = w.weather_hour_key;

-- 8. Row Reconciliation
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
  g.gold_row_count - s.silver_row_count AS row_count_difference,
  ROUND(100.0 * g.gold_row_count / NULLIF(s.silver_row_count, 0), 3) AS gold_retention_pct
FROM silver_summary AS s
CROSS JOIN gold_summary AS g;

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