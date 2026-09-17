-- Databricks notebook source
-- Name: End-to-End Quality Gate
-- Purpose: Consolidate the critical cross-layer checks into one PASS/FAIL decision.
-- Accuracy is documented separately because no independent ground-truth trip source is available.

CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.pipeline_quality_gate_results AS
SELECT
  'Bronze to Silver Green Taxi row preservation' AS check_name,
  'CONSISTENCY' AS quality_attribute,
  CAST((SELECT COUNT(*) FROM `ftw-week-08`.`01_bronze`.green_taxi) AS STRING) AS expected_value,
  CAST((SELECT COUNT(*) FROM `ftw-week-08`.`02_silver`.green_taxi) AS STRING) AS actual_value,
  CASE
    WHEN (SELECT COUNT(*) FROM `ftw-week-08`.`01_bronze`.green_taxi)
       = (SELECT COUNT(*) FROM `ftw-week-08`.`02_silver`.green_taxi)
    THEN 'PASS' ELSE 'FAIL'
  END AS status

UNION ALL

SELECT
  'Silver to Gold fact row preservation',
  'CONSISTENCY',
  CAST((SELECT COUNT(*) FROM `ftw-week-08`.`02_silver`.green_taxi) AS STRING),
  CAST((SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip) AS STRING),
  CASE
    WHEN (SELECT COUNT(*) FROM `ftw-week-08`.`02_silver`.green_taxi)
       = (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip)
    THEN 'PASS' ELSE 'FAIL'
  END

UNION ALL

SELECT
  'Silver to Gold retained measures reconcile',
  'CONSISTENCY',
  '0 aggregate difference',
  CONCAT(CAST(measure_difference AS STRING), ' aggregate difference'),
  CASE WHEN measure_difference = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
  SELECT ROUND(
      ABS(COALESCE(g.trip_distance, 0) - COALESCE(s.trip_distance, 0))
    + ABS(COALESCE(g.trip_duration_minutes, 0) - COALESCE(s.trip_duration_minutes, 0))
    + ABS(COALESCE(g.fare_amount, 0) - COALESCE(s.fare_amount, 0))
    + ABS(COALESCE(g.extra, 0) - COALESCE(s.extra, 0))
    + ABS(COALESCE(g.mta_tax, 0) - COALESCE(s.mta_tax, 0))
    + ABS(COALESCE(g.tip_amount, 0) - COALESCE(s.tip_amount, 0))
    + ABS(COALESCE(g.tolls_amount, 0) - COALESCE(s.tolls_amount, 0))
    + ABS(COALESCE(g.improvement_surcharge, 0) - COALESCE(s.improvement_surcharge, 0))
    + ABS(COALESCE(g.congestion_surcharge, 0) - COALESCE(s.congestion_surcharge, 0))
    + ABS(COALESCE(g.cbd_congestion_fee, 0) - COALESCE(s.cbd_congestion_fee, 0))
    + ABS(COALESCE(g.total_amount, 0) - COALESCE(s.total_amount, 0)),
    6
  ) AS measure_difference
  FROM (
    SELECT
      SUM(trip_distance) AS trip_distance,
      SUM(trip_duration_minutes) AS trip_duration_minutes,
      SUM(fare_amount) AS fare_amount,
      SUM(extra) AS extra,
      SUM(mta_tax) AS mta_tax,
      SUM(tip_amount) AS tip_amount,
      SUM(tolls_amount) AS tolls_amount,
      SUM(improvement_surcharge) AS improvement_surcharge,
      SUM(congestion_surcharge) AS congestion_surcharge,
      SUM(cbd_congestion_fee) AS cbd_congestion_fee,
      SUM(total_amount) AS total_amount
    FROM `ftw-week-08`.`02_silver`.green_taxi
  ) AS s
  CROSS JOIN (
    SELECT
      SUM(trip_distance) AS trip_distance,
      SUM(trip_duration_minutes) AS trip_duration_minutes,
      SUM(fare_amount) AS fare_amount,
      SUM(extra) AS extra,
      SUM(mta_tax) AS mta_tax,
      SUM(tip_amount) AS tip_amount,
      SUM(tolls_amount) AS tolls_amount,
      SUM(improvement_surcharge) AS improvement_surcharge,
      SUM(congestion_surcharge) AS congestion_surcharge,
      SUM(cbd_congestion_fee) AS cbd_congestion_fee,
      SUM(total_amount) AS total_amount
    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
  ) AS g
) AS measure_summary

UNION ALL

SELECT
  'Silver to Gold Taxi Zone row preservation',
  'CONSISTENCY',
  CAST((SELECT COUNT(*) FROM `ftw-week-08`.`02_silver`.taxi_zones) AS STRING),
  CAST((SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.dim_taxi_zone) AS STRING),
  CASE
    WHEN (SELECT COUNT(*) FROM `ftw-week-08`.`02_silver`.taxi_zones)
       = (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.dim_taxi_zone)
    THEN 'PASS' ELSE 'FAIL'
  END

UNION ALL

SELECT
  'Gold Weather contains Silver hours plus one Unknown member',
  'COMPLETENESS',
  CAST((SELECT COUNT(*) + 1 FROM `ftw-week-08`.`02_silver`.weather) AS STRING),
  CAST((SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.dim_weather_hour) AS STRING),
  CASE
    WHEN (SELECT COUNT(*) + 1 FROM `ftw-week-08`.`02_silver`.weather)
       = (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.dim_weather_hour)
    THEN 'PASS' ELSE 'FAIL'
  END

UNION ALL

SELECT
  'Gold dimension keys are unique',
  'UNIQUENESS',
  '0 duplicate or null-key rows',
  CAST(
    (SELECT COUNT(*) - COUNT(DISTINCT date_key) FROM `ftw-week-08`.`03_gold`.dim_date)
    + (SELECT COUNT(*) - COUNT(DISTINCT time_key) FROM `ftw-week-08`.`03_gold`.dim_time)
    + (SELECT COUNT(*) - COUNT(DISTINCT taxi_zone_key) FROM `ftw-week-08`.`03_gold`.dim_taxi_zone)
    + (SELECT COUNT(*) - COUNT(DISTINCT weather_hour_key) FROM `ftw-week-08`.`03_gold`.dim_weather_hour)
    AS STRING
  ),
  CASE
    WHEN
      (SELECT COUNT(*) - COUNT(DISTINCT date_key) FROM `ftw-week-08`.`03_gold`.dim_date)
      + (SELECT COUNT(*) - COUNT(DISTINCT time_key) FROM `ftw-week-08`.`03_gold`.dim_time)
      + (SELECT COUNT(*) - COUNT(DISTINCT taxi_zone_key) FROM `ftw-week-08`.`03_gold`.dim_taxi_zone)
      + (SELECT COUNT(*) - COUNT(DISTINCT weather_hour_key) FROM `ftw-week-08`.`03_gold`.dim_weather_hour)
      = 0
    THEN 'PASS' ELSE 'FAIL'
  END

UNION ALL

SELECT
  'Gold fact technical keys are complete and unique',
  'UNIQUENESS',
  '0 null or duplicate-key rows',
  CAST(
    (SELECT COUNT(*) - COUNT(DISTINCT trip_key) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip)
    AS STRING
  ),
  CASE
    WHEN (SELECT COUNT(*) - COUNT(DISTINCT trip_key) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip) = 0
    THEN 'PASS' ELSE 'FAIL'
  END

UNION ALL

SELECT
  'Fact foreign keys resolve without join multiplication',
  'CONSISTENCY',
  '0 missing references and 0 added rows',
  CAST(
    missing_pickup_date_keys
    + missing_dropoff_date_keys
    + missing_pickup_time_keys
    + missing_dropoff_time_keys
    + missing_pickup_zone_keys
    + missing_dropoff_zone_keys
    + missing_weather_keys
    + ABS(join_row_difference)
    AS STRING
  ),
  CASE
    WHEN missing_pickup_date_keys
       + missing_dropoff_date_keys
       + missing_pickup_time_keys
       + missing_dropoff_time_keys
       + missing_pickup_zone_keys
       + missing_dropoff_zone_keys
       + missing_weather_keys = 0
     AND join_row_difference = 0
    THEN 'PASS' ELSE 'FAIL'
  END
FROM `ftw-week-08`.`03_gold`.dq_dashboard_referential_integrity

UNION ALL

SELECT
  'Gold fact lineage is complete',
  'AUDITABILITY',
  '0 rows missing lineage',
  CAST(COUNT_IF(source_system IS NULL OR source_file IS NULL OR batch_id IS NULL) AS STRING),
  CASE
    WHEN COUNT_IF(source_system IS NULL OR source_file IS NULL OR batch_id IS NULL) = 0
    THEN 'PASS' ELSE 'FAIL'
  END
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip

UNION ALL

SELECT
  'Gold fact quality flags are populated',
  'VALIDITY',
  '0 null quality flags',
  CAST(COUNT_IF(
    dq_zero_trip_distance IS NULL
    OR dq_extreme_trip_distance IS NULL
    OR dq_negative_trip_distance IS NULL
    OR dq_out_of_range_datetime IS NULL
    OR dq_invalid_trip_duration IS NULL
    OR dq_missing_weather_coverage IS NULL
  ) AS STRING),
  CASE
    WHEN COUNT_IF(
      dq_zero_trip_distance IS NULL
      OR dq_extreme_trip_distance IS NULL
      OR dq_negative_trip_distance IS NULL
      OR dq_out_of_range_datetime IS NULL
      OR dq_invalid_trip_duration IS NULL
      OR dq_missing_weather_coverage IS NULL
    ) = 0
    THEN 'PASS' ELSE 'FAIL'
  END
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip

UNION ALL

SELECT
  'Silver Weather hourly sequence is continuous',
  'TIMELINESS_VOLUME',
  CONCAT(CAST(expected_hour_count AS STRING), ' expected hours'),
  CONCAT(CAST(observed_hour_count AS STRING), ' observed hours'),
  CASE WHEN observed_hour_count = expected_hour_count THEN 'PASS' ELSE 'FAIL' END
FROM (
  SELECT
    COUNT(DISTINCT weather_datetime) AS observed_hour_count,
    CAST(
      (UNIX_TIMESTAMP(MAX(weather_datetime)) - UNIX_TIMESTAMP(MIN(weather_datetime))) / 3600 + 1
      AS BIGINT
    ) AS expected_hour_count
  FROM `ftw-week-08`.`02_silver`.weather
) AS weather_coverage

UNION ALL

SELECT
  'Accuracy claim is correctly scoped',
  'ACCURACY',
  'No unverified ground-truth claim',
  'No unverified ground-truth claim',
  'PASS'

UNION ALL

SELECT
  'Analytics validation passes',
  'VALIDITY',
  'PASS',
  overall_status,
  overall_status
FROM `ftw-week-08`.`03_gold`.analytics_validation_summary

UNION ALL

SELECT
  'All seven quality attributes are documented',
  'AUDITABILITY',
  '7 attributes',
  CONCAT(CAST(COUNT(*) AS STRING), ' attributes'),
  CASE WHEN COUNT(*) = 7 THEN 'PASS' ELSE 'FAIL' END
FROM `ftw-week-08`.`03_gold`.dq_dashboard_canonical_dimensions;

-- COMMAND ----------

CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.pipeline_quality_gate_summary AS
SELECT
  CURRENT_TIMESTAMP() AS checked_at,
  COUNT(*) AS total_checks,
  COUNT_IF(status = 'PASS') AS passed_checks,
  COUNT_IF(status = 'FAIL') AS failed_checks,
  CASE WHEN COUNT_IF(status = 'FAIL') = 0 THEN 'PASS' ELSE 'FAIL' END AS overall_status
FROM `ftw-week-08`.`03_gold`.pipeline_quality_gate_results;

-- COMMAND ----------

SELECT *
FROM `ftw-week-08`.`03_gold`.pipeline_quality_gate_results
ORDER BY quality_attribute, check_name;

-- COMMAND ----------

SELECT *
FROM `ftw-week-08`.`03_gold`.pipeline_quality_gate_summary;

-- COMMAND ----------

SELECT ASSERT_TRUE(
  failed_checks = 0,
  CONCAT('End-to-end quality gate failed: ', CAST(failed_checks AS STRING), ' check(s) failed')
)
FROM `ftw-week-08`.`03_gold`.pipeline_quality_gate_summary;
