-- Databricks notebook source
-- 3. Check Scores
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_check_scores AS
WITH aggregated_checks AS (
  SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(f.dq_zero_trip_distance) AS zero_dist,
    COUNT_IF(f.dq_extreme_trip_distance) AS extreme_dist,
    COUNT_IF(f.dq_negative_trip_distance) AS neg_dist,
    COUNT_IF(f.dq_invalid_trip_duration) AS invalid_dur,
    COUNT_IF(f.dq_missing_weather_coverage) AS missing_weather,
    COUNT_IF(z.taxi_zone_key IS NULL) AS unmapped_zone,
    COUNT_IF(f.trip_key IS NULL) AS null_key,
    COUNT_IF(
      f.source_system IS NULL
      OR f.source_file IS NULL
      OR f.batch_id IS NULL
    ) AS missing_lineage
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
  LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z
    ON f.pickup_taxi_zone_key = z.taxi_zone_key
),
dup_check AS (
  SELECT COALESCE(SUM(key_count - 1), 0) AS dup_key
  FROM (
    SELECT COUNT(*) AS key_count
    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
    WHERE trip_key IS NOT NULL
    GROUP BY trip_key
    HAVING COUNT(*) > 1
  )
)
SELECT
  check_name,
  quality_dimension,
  flagged_rows,
  total_rows,
  ROUND(100.0 * flagged_rows / NULLIF(total_rows, 0), 3) AS flagged_pct
FROM (
  SELECT 'Zero trip distance' AS check_name, 'VALIDITY' AS quality_dimension, zero_dist AS flagged_rows, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Extreme trip distance', 'VALIDITY', extreme_dist, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Negative trip distance', 'VALIDITY', neg_dist, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Invalid trip duration', 'VALIDITY', invalid_dur, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Missing weather coverage', 'COMPLETENESS', missing_weather, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Unknown / unmapped pickup zone', 'COMPLETENESS', unmapped_zone, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Null trip key', 'UNIQUENESS', null_key, total_rows FROM aggregated_checks
  UNION ALL SELECT 'Duplicate trip key', 'UNIQUENESS', d.dup_key, a.total_rows FROM aggregated_checks a CROSS JOIN dup_check d
  UNION ALL SELECT 'Missing source lineage', 'AUDITABILITY', missing_lineage, total_rows FROM aggregated_checks
)
ORDER BY flagged_rows DESC;
