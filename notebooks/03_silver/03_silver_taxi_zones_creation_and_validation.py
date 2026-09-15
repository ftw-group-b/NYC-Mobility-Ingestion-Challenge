# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# DBTITLE 1,Title
# MAGIC %md
# MAGIC # Silver Layer: Taxi Zones Creation & Validation
# MAGIC
# MAGIC This notebook creates the Silver layer table for Taxi Zones from Bronze, applying type casting and running comprehensive validation checks.
# MAGIC
# MAGIC Source: `ftw-week-08`.`01_bronze`  →  Target: `ftw-week-08`.`02_silver`

# COMMAND ----------

# DBTITLE 1,Section: Taxi Zones Silver
# MAGIC %md
# MAGIC ## 1. Taxi Zones Silver
# MAGIC
# MAGIC Create the Silver `taxi_zones` table from Bronze with type casting for all columns.

# COMMAND ----------

# DBTITLE 1,Create Silver Table for Taxi Zones
# MAGIC %sql
# MAGIC CREATE OR REPLACE TABLE `ftw-week-08`.`02_silver`.`taxi_zones`
# MAGIC USING DELTA
# MAGIC AS
# MAGIC SELECT
# MAGIC     CAST(LocationID AS INT) AS LocationID,
# MAGIC     CAST(Borough AS STRING) AS Borough,
# MAGIC     CAST(Zone AS STRING) AS Zone,
# MAGIC     CAST(service_zone AS STRING) AS service_zone
# MAGIC FROM `ftw-week-08`.`01_bronze`.`taxi_zones`

# COMMAND ----------

# DBTITLE 1,Section: Taxi Zones Validation
# MAGIC %md
# MAGIC ## 2. Taxi Zones Validation
# MAGIC
# MAGIC Validation checks for the Silver `taxi_zones` table:
# MAGIC - Source vs Silver row count
# MAGIC - NULL checks on all columns
# MAGIC - Duplicate LocationID check
# MAGIC - LocationID range and distinct-count check
# MAGIC - Pickup/dropoff orphan checks against Bronze Green Taxi
# MAGIC - Final PASS/FAIL validation summary

# COMMAND ----------

# DBTITLE 1,Validation 1: Row Count Comparison
# MAGIC %sql
# MAGIC -- Compare source and Silver row counts
# MAGIC SELECT
# MAGIC     'Source (Bronze)' AS table_name,
# MAGIC     COUNT(*) AS row_count
# MAGIC FROM `ftw-week-08`.`01_bronze`.`taxi_zones`
# MAGIC
# MAGIC UNION ALL
# MAGIC
# MAGIC SELECT
# MAGIC     'Target (Silver)' AS table_name,
# MAGIC     COUNT(*) AS row_count
# MAGIC FROM `ftw-week-08`.`02_silver`.`taxi_zones`

# COMMAND ----------

# DBTITLE 1,Validation 2: NULL Check
# MAGIC %sql
# MAGIC -- Check for NULL values in all columns
# MAGIC SELECT
# MAGIC     COUNT(*) AS total_rows,
# MAGIC     COUNT_IF(LocationID IS NULL) AS null_location_id,
# MAGIC     COUNT_IF(Borough IS NULL) AS null_borough,
# MAGIC     COUNT_IF(Zone IS NULL) AS null_zone,
# MAGIC     COUNT_IF(service_zone IS NULL) AS null_service_zone
# MAGIC FROM `ftw-week-08`.`02_silver`.`taxi_zones`

# COMMAND ----------

# DBTITLE 1,Validation 3: Duplicate LocationID Check
# MAGIC %sql
# MAGIC -- Check for duplicate LocationIDs
# MAGIC SELECT
# MAGIC     LocationID,
# MAGIC     COUNT(*) AS record_count
# MAGIC FROM `ftw-week-08`.`02_silver`.`taxi_zones`
# MAGIC GROUP BY LocationID
# MAGIC HAVING COUNT(*) > 1

# COMMAND ----------

# DBTITLE 1,Validation 4: LocationID Range
# MAGIC %sql
# MAGIC -- Check LocationID range and distinct count
# MAGIC SELECT
# MAGIC     MIN(LocationID) AS min_location_id,
# MAGIC     MAX(LocationID) AS max_location_id,
# MAGIC     COUNT(DISTINCT LocationID) AS distinct_location_ids
# MAGIC FROM `ftw-week-08`.`02_silver`.`taxi_zones`

# COMMAND ----------

# DBTITLE 1,Validation 5: Green Taxi Referential Integrity
# MAGIC %sql
# MAGIC -- Check for orphan pickup and dropoff location IDs
# MAGIC SELECT
# MAGIC     'pickup' AS location_type,
# MAGIC     COUNT(*) AS orphan_rows
# MAGIC FROM `ftw-week-08`.`01_bronze`.`green_taxi` g
# MAGIC LEFT JOIN `ftw-week-08`.`02_silver`.`taxi_zones` z
# MAGIC     ON g.PULocationID = z.LocationID
# MAGIC WHERE g.PULocationID IS NOT NULL
# MAGIC   AND z.LocationID IS NULL
# MAGIC
# MAGIC UNION ALL
# MAGIC
# MAGIC SELECT
# MAGIC     'dropoff' AS location_type,
# MAGIC     COUNT(*) AS orphan_rows
# MAGIC FROM `ftw-week-08`.`01_bronze`.`green_taxi` g
# MAGIC LEFT JOIN `ftw-week-08`.`02_silver`.`taxi_zones` z
# MAGIC     ON g.DOLocationID = z.LocationID
# MAGIC WHERE g.DOLocationID IS NOT NULL
# MAGIC   AND z.LocationID IS NULL

# COMMAND ----------

# DBTITLE 1,Validation 6: Final Validation Summary
# MAGIC %sql
# MAGIC -- Final validation summary with Pass/Fail status
# MAGIC WITH validation_results AS (
# MAGIC     SELECT
# MAGIC         (SELECT COUNT(*) FROM `ftw-week-08`.`01_bronze`.`taxi_zones`) AS source_count,
# MAGIC         (SELECT COUNT(*) FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS silver_count,
# MAGIC         (SELECT COUNT_IF(LocationID IS NULL) FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_location_id,
# MAGIC         (SELECT COUNT_IF(Borough IS NULL) FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_borough,
# MAGIC         (SELECT COUNT_IF(Zone IS NULL) FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_zone,
# MAGIC         (SELECT COUNT_IF(service_zone IS NULL) FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_service_zone,
# MAGIC         (SELECT COUNT(*) FROM (
# MAGIC             SELECT LocationID, COUNT(*) AS cnt
# MAGIC             FROM `ftw-week-08`.`02_silver`.`taxi_zones`
# MAGIC             GROUP BY LocationID
# MAGIC             HAVING COUNT(*) > 1
# MAGIC         )) AS duplicate_location_id,
# MAGIC         (SELECT COUNT(DISTINCT LocationID) FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS distinct_location_ids,
# MAGIC         (SELECT MIN(LocationID) FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS min_location_id,
# MAGIC         (SELECT MAX(LocationID) FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS max_location_id,
# MAGIC         (SELECT COUNT(*) FROM `ftw-week-08`.`01_bronze`.`green_taxi` g
# MAGIC          LEFT JOIN `ftw-week-08`.`02_silver`.`taxi_zones` z ON g.PULocationID = z.LocationID
# MAGIC          WHERE g.PULocationID IS NOT NULL AND z.LocationID IS NULL) AS orphan_pickup,
# MAGIC         (SELECT COUNT(*) FROM `ftw-week-08`.`01_bronze`.`green_taxi` g
# MAGIC          LEFT JOIN `ftw-week-08`.`02_silver`.`taxi_zones` z ON g.DOLocationID = z.LocationID
# MAGIC          WHERE g.DOLocationID IS NOT NULL AND z.LocationID IS NULL) AS orphan_dropoff
# MAGIC )
# MAGIC SELECT
# MAGIC     check_name,
# MAGIC     expected,
# MAGIC     actual,
# MAGIC     CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS status
# MAGIC FROM (
# MAGIC     SELECT 'Source row count' AS check_name, 265 AS expected, source_count AS actual FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'Silver row count', 265, silver_count FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'NULL LocationID', 0, null_location_id FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'NULL Borough', 0, null_borough FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'NULL Zone', 0, null_zone FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'NULL service_zone', 0, null_service_zone FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'Duplicate LocationID', 0, duplicate_location_id FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'Distinct LocationID', 265, distinct_location_ids FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'Minimum LocationID', 1, min_location_id FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'Maximum LocationID', 265, max_location_id FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'Orphan pickup IDs', 0, orphan_pickup FROM validation_results
# MAGIC     UNION ALL
# MAGIC     SELECT 'Orphan dropoff IDs', 0, orphan_dropoff FROM validation_results
# MAGIC )
# MAGIC ORDER BY
# MAGIC     CASE check_name
# MAGIC         WHEN 'Source row count' THEN 1
# MAGIC         WHEN 'Silver row count' THEN 2
# MAGIC         WHEN 'NULL LocationID' THEN 3
# MAGIC         WHEN 'NULL Borough' THEN 4
# MAGIC         WHEN 'NULL Zone' THEN 5
# MAGIC         WHEN 'NULL service_zone' THEN 6
# MAGIC         WHEN 'Duplicate LocationID' THEN 7
# MAGIC         WHEN 'Distinct LocationID' THEN 8
# MAGIC         WHEN 'Minimum LocationID' THEN 9
# MAGIC         WHEN 'Maximum LocationID' THEN 10
# MAGIC         WHEN 'Orphan pickup IDs' THEN 11
# MAGIC         WHEN 'Orphan dropoff IDs' THEN 12
# MAGIC     END