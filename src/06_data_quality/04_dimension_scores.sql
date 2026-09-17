-- Databricks notebook source
-- 4. Dimension Scores
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_dimension_scores AS
WITH fact_summary AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(
      f.dq_zero_trip_distance
      OR f.dq_extreme_trip_distance
      OR f.dq_negative_trip_distance
      OR f.dq_invalid_trip_duration
    ) AS validity_flagged_rows,
    COUNT_IF(
      f.dq_missing_weather_coverage
      OR z.taxi_zone_key IS NULL
    ) AS completeness_flagged_rows,
    COUNT_IF(f.trip_key IS NULL) AS null_trip_key_rows,
    COUNT_IF(
      f.source_system IS NULL
      OR f.source_file IS NULL
      OR f.batch_id IS NULL
    ) AS auditability_flagged_rows
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z
    ON f.pickup_taxi_zone_key = z.taxi_zone_key
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
  UNION ALL
  SELECT
    'AUDITABILITY',
    auditability_flagged_rows,
    total_rows,
    1 AS checks_in_dimension
  FROM fact_summary
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
