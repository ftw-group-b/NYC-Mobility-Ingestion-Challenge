-- Databricks notebook source
-- Name: Business Analytics Validation
-- Purpose: Validate the three dashboard-ready analytics views separately from their creation.
-- PASS standard: all declared grains are unique and all trip-volume totals reconcile with the in-scope Gold fact.

CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.analytics_validation_results AS
WITH fact_scope AS (
  SELECT COUNT(*) AS in_scope_fact_rows
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
  WHERE dq_out_of_range_datetime = FALSE
),
taxi_demand_duplicate_grain AS (
  SELECT COUNT(*) AS duplicate_groups
  FROM (
    SELECT
      pickup_date,
      pickup_hour_24,
      pickup_taxi_zone_key,
      COUNT(*) AS group_rows
    FROM `ftw-week-08`.`03_gold`.analytics_taxi_demand
    GROUP BY pickup_date, pickup_hour_24, pickup_taxi_zone_key
    HAVING COUNT(*) > 1
  )
),
area_duplicate_grain AS (
  SELECT COUNT(*) AS duplicate_groups
  FROM (
    SELECT taxi_zone_key, COUNT(*) AS group_rows
    FROM `ftw-week-08`.`03_gold`.analytics_area_mobility_patterns
    GROUP BY taxi_zone_key
    HAVING COUNT(*) > 1
  )
)
SELECT
  'Taxi demand view contains rows' AS check_name,
  'COMPLETENESS' AS quality_attribute,
  '> 0' AS expected_value,
  CAST(COUNT(*) AS STRING) AS actual_value,
  CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM `ftw-week-08`.`03_gold`.analytics_taxi_demand

UNION ALL

SELECT
  'Taxi demand declared grain is unique',
  'UNIQUENESS',
  '0 duplicate groups',
  CONCAT(CAST(duplicate_groups AS STRING), ' duplicate groups'),
  CASE WHEN duplicate_groups = 0 THEN 'PASS' ELSE 'FAIL' END
FROM taxi_demand_duplicate_grain

UNION ALL

SELECT
  'Taxi demand uses clock hours 0-23',
  'VALIDITY',
  '0 invalid hours',
  CONCAT(CAST(COUNT_IF(pickup_hour_24 NOT BETWEEN 0 AND 23) AS STRING), ' invalid hours'),
  CASE
    WHEN COUNT_IF(pickup_hour_24 NOT BETWEEN 0 AND 23) = 0 THEN 'PASS'
    ELSE 'FAIL'
  END
FROM `ftw-week-08`.`03_gold`.analytics_taxi_demand

UNION ALL

SELECT
  'Taxi demand trip volume reconciles with Gold',
  'CONSISTENCY',
  CAST(f.in_scope_fact_rows AS STRING),
  CAST(COALESCE(SUM(a.trip_volume), 0) AS STRING),
  CASE
    WHEN COALESCE(SUM(a.trip_volume), 0) = f.in_scope_fact_rows THEN 'PASS'
    ELSE 'FAIL'
  END
FROM `ftw-week-08`.`03_gold`.analytics_taxi_demand AS a
CROSS JOIN fact_scope AS f
GROUP BY f.in_scope_fact_rows

UNION ALL

SELECT
  'Weather behavior view contains rows',
  'COMPLETENESS',
  '> 0',
  CAST(COUNT(*) AS STRING),
  CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM `ftw-week-08`.`03_gold`.analytics_weather_behavior

UNION ALL

SELECT
  'Weather behavior trip volume reconciles with Gold',
  'CONSISTENCY',
  CAST(f.in_scope_fact_rows AS STRING),
  CAST(COALESCE(SUM(a.trip_volume), 0) AS STRING),
  CASE
    WHEN COALESCE(SUM(a.trip_volume), 0) = f.in_scope_fact_rows THEN 'PASS'
    ELSE 'FAIL'
  END
FROM `ftw-week-08`.`03_gold`.analytics_weather_behavior AS a
CROSS JOIN fact_scope AS f
GROUP BY f.in_scope_fact_rows

UNION ALL

SELECT
  'Area mobility view contains rows',
  'COMPLETENESS',
  '> 0',
  CAST(COUNT(*) AS STRING),
  CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END
FROM `ftw-week-08`.`03_gold`.analytics_area_mobility_patterns

UNION ALL

SELECT
  'Area mobility declared grain is unique',
  'UNIQUENESS',
  '0 duplicate groups',
  CONCAT(CAST(duplicate_groups AS STRING), ' duplicate groups'),
  CASE WHEN duplicate_groups = 0 THEN 'PASS' ELSE 'FAIL' END
FROM area_duplicate_grain

UNION ALL

SELECT
  'Area pickup volume reconciles with Gold',
  'CONSISTENCY',
  CAST(f.in_scope_fact_rows AS STRING),
  CAST(COALESCE(SUM(a.pickup_trip_volume), 0) AS STRING),
  CASE
    WHEN COALESCE(SUM(a.pickup_trip_volume), 0) = f.in_scope_fact_rows THEN 'PASS'
    ELSE 'FAIL'
  END
FROM `ftw-week-08`.`03_gold`.analytics_area_mobility_patterns AS a
CROSS JOIN fact_scope AS f
GROUP BY f.in_scope_fact_rows

UNION ALL

SELECT
  'Area drop-off volume reconciles with Gold',
  'CONSISTENCY',
  CAST(f.in_scope_fact_rows AS STRING),
  CAST(COALESCE(SUM(a.dropoff_trip_volume), 0) AS STRING),
  CASE
    WHEN COALESCE(SUM(a.dropoff_trip_volume), 0) = f.in_scope_fact_rows THEN 'PASS'
    ELSE 'FAIL'
  END
FROM `ftw-week-08`.`03_gold`.analytics_area_mobility_patterns AS a
CROSS JOIN fact_scope AS f
GROUP BY f.in_scope_fact_rows;

-- COMMAND ----------

CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.analytics_validation_summary AS
SELECT
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS total_checks,
  COUNT_IF(status = 'PASS') AS passed_checks,
  COUNT_IF(status = 'FAIL') AS failed_checks,
  CASE WHEN COUNT_IF(status = 'FAIL') = 0 THEN 'PASS' ELSE 'FAIL' END AS overall_status
FROM `ftw-week-08`.`03_gold`.analytics_validation_results;

-- COMMAND ----------

SELECT *
FROM `ftw-week-08`.`03_gold`.analytics_validation_results
ORDER BY quality_attribute, check_name;

-- COMMAND ----------

SELECT *
FROM `ftw-week-08`.`03_gold`.analytics_validation_summary;

-- COMMAND ----------

SELECT ASSERT_TRUE(
  failed_checks = 0,
  CONCAT('Analytics validation failed: ', CAST(failed_checks AS STRING), ' check(s) failed')
)
FROM `ftw-week-08`.`03_gold`.analytics_validation_summary;
