# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# DBTITLE 1,Title
# MAGIC %md
# MAGIC # Silver Layer: Taxi Zones Creation & Validation
# MAGIC
# MAGIC This notebook creates the Silver layer table for Taxi Zones from Bronze, applying type casting and preserving ingestion metadata. It then runs validation checks for completeness, uniqueness, data quality, and referential integrity.
# MAGIC
# MAGIC Source: `ftw-week-08`.`01_bronze`  →  Target: `ftw-week-08`.`02_silver`

# COMMAND ----------

# DBTITLE 1,Section: Taxi Zones Silver
# MAGIC %md
# MAGIC ## 1. Taxi Zones Silver
# MAGIC
# MAGIC Create the Silver `taxi_zones` table from Bronze, applying type casting to the business columns and preserving ingestion metadata.

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
# MAGIC     CAST(service_zone AS STRING) AS service_zone,
# MAGIC     source_system,
# MAGIC     source_file,
# MAGIC     batch_id,
# MAGIC     ingested_at
# MAGIC FROM `ftw-week-08`.`01_bronze`.`taxi_zones`

# COMMAND ----------

# DBTITLE 1,Section: Taxi Zones Validation
# MAGIC %md
# MAGIC ## 2. Taxi Zones Validation
# MAGIC
# MAGIC Validation checks for the Silver `taxi_zones` table:
# MAGIC - Source vs Silver row count
# MAGIC - NULL checks on business columns
# MAGIC - Duplicate LocationID check
# MAGIC - LocationID range and distinct-count check
# MAGIC - Blank/space-only Zone profiling
# MAGIC - Pickup/dropoff referential integrity checks against Silver Green Taxi
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
# MAGIC -- Check for NULL values in all Silver columns
# MAGIC SELECT
# MAGIC     COUNT(*) AS total_rows,
# MAGIC     COUNT_IF(LocationID IS NULL) AS null_location_id,
# MAGIC     COUNT_IF(Borough IS NULL) AS null_borough,
# MAGIC     COUNT_IF(Zone IS NULL) AS null_zone,
# MAGIC     COUNT_IF(service_zone IS NULL) AS null_service_zone,
# MAGIC     COUNT_IF(source_system IS NULL) AS null_source_system,
# MAGIC     COUNT_IF(source_file IS NULL) AS null_source_file,
# MAGIC     COUNT_IF(batch_id IS NULL) AS null_batch_id,
# MAGIC     COUNT_IF(ingested_at IS NULL) AS null_ingested_at
# MAGIC FROM `ftw-week-08`.`02_silver`.`taxi_zones`;

# COMMAND ----------

# DBTITLE 1,blank/space-only profiling check
# MAGIC %sql
# MAGIC -- Profile blank or space-only Zone values
# MAGIC SELECT
# MAGIC     COUNT(*) AS total_rows,
# MAGIC     COUNT_IF(Zone IS NULL) AS null_zone,
# MAGIC     COUNT_IF(Zone IS NOT NULL AND TRIM(Zone) = '') AS blank_or_space_zone,
# MAGIC     COUNT_IF(Zone IS NOT NULL AND TRIM(Zone) <> '') AS populated_zone
# MAGIC FROM `ftw-week-08`.`02_silver`.`taxi_zones`;

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
# MAGIC -- Validate Silver Green Taxi references against Silver Taxi Zones
# MAGIC
# MAGIC SELECT
# MAGIC     'pickup' AS location_type,
# MAGIC     COUNT(*) AS orphan_rows
# MAGIC FROM `ftw-week-08`.`02_silver`.`green_taxi` g
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
# MAGIC FROM `ftw-week-08`.`02_silver`.`green_taxi` g
# MAGIC LEFT JOIN `ftw-week-08`.`02_silver`.`taxi_zones` z
# MAGIC     ON g.DOLocationID = z.LocationID
# MAGIC WHERE g.DOLocationID IS NOT NULL
# MAGIC   AND z.LocationID IS NULL;

# COMMAND ----------

# DBTITLE 1,Validation 6: Final Validation Summary
# MAGIC %sql
# MAGIC -- Final validation summary with Pass/Fail status
# MAGIC WITH validation_results AS (
# MAGIC     SELECT
# MAGIC         -- Row counts
# MAGIC         (SELECT COUNT(*)
# MAGIC          FROM `ftw-week-08`.`01_bronze`.`taxi_zones`) AS source_count,
# MAGIC
# MAGIC         (SELECT COUNT(*)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS silver_count,
# MAGIC
# MAGIC         -- NULL checks
# MAGIC         (SELECT COUNT_IF(LocationID IS NULL)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_location_id,
# MAGIC
# MAGIC         (SELECT COUNT_IF(Borough IS NULL)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_borough,
# MAGIC
# MAGIC         (SELECT COUNT_IF(Zone IS NULL)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_zone,
# MAGIC
# MAGIC         (SELECT COUNT_IF(service_zone IS NULL)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_service_zone,
# MAGIC
# MAGIC         -- Lineage metadata NULL checks
# MAGIC         (SELECT COUNT_IF(source_system IS NULL)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_source_system,
# MAGIC
# MAGIC         (SELECT COUNT_IF(source_file IS NULL)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_source_file,
# MAGIC
# MAGIC         (SELECT COUNT_IF(batch_id IS NULL)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_batch_id,
# MAGIC
# MAGIC         (SELECT COUNT_IF(ingested_at IS NULL)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS null_ingested_at,
# MAGIC
# MAGIC         -- Uniqueness
# MAGIC         (SELECT COUNT(*)
# MAGIC          FROM (
# MAGIC              SELECT LocationID, COUNT(*) AS cnt
# MAGIC              FROM `ftw-week-08`.`02_silver`.`taxi_zones`
# MAGIC              GROUP BY LocationID
# MAGIC              HAVING COUNT(*) > 1
# MAGIC          )) AS duplicate_location_id,
# MAGIC
# MAGIC         -- LocationID validation
# MAGIC         (SELECT COUNT(DISTINCT LocationID)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS distinct_location_ids,
# MAGIC
# MAGIC         (SELECT MIN(LocationID)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS min_location_id,
# MAGIC
# MAGIC         (SELECT MAX(LocationID)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`taxi_zones`) AS max_location_id,
# MAGIC
# MAGIC         -- Referential integrity: Silver Green Taxi → Silver Taxi Zones
# MAGIC         (SELECT COUNT(*)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`green_taxi` g
# MAGIC          LEFT JOIN `ftw-week-08`.`02_silver`.`taxi_zones` z
# MAGIC              ON g.PULocationID = z.LocationID
# MAGIC          WHERE g.PULocationID IS NOT NULL
# MAGIC            AND z.LocationID IS NULL) AS orphan_pickup,
# MAGIC
# MAGIC         (SELECT COUNT(*)
# MAGIC          FROM `ftw-week-08`.`02_silver`.`green_taxi` g
# MAGIC          LEFT JOIN `ftw-week-08`.`02_silver`.`taxi_zones` z
# MAGIC              ON g.DOLocationID = z.LocationID
# MAGIC          WHERE g.DOLocationID IS NOT NULL
# MAGIC            AND z.LocationID IS NULL) AS orphan_dropoff
# MAGIC )
# MAGIC
# MAGIC SELECT
# MAGIC     check_name,
# MAGIC     expected,
# MAGIC     actual,
# MAGIC     CASE
# MAGIC         WHEN expected = actual THEN 'PASS'
# MAGIC         ELSE 'FAIL'
# MAGIC     END AS status
# MAGIC FROM (
# MAGIC     SELECT 'Source row count' AS check_name,
# MAGIC            265 AS expected,
# MAGIC            source_count AS actual
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'Silver row count',
# MAGIC            265,
# MAGIC            silver_count
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'NULL LocationID',
# MAGIC            0,
# MAGIC            null_location_id
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'NULL Borough',
# MAGIC            0,
# MAGIC            null_borough
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'NULL Zone',
# MAGIC            0,
# MAGIC            null_zone
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'NULL service_zone',
# MAGIC            0,
# MAGIC            null_service_zone
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'NULL source_system',
# MAGIC            0,
# MAGIC            null_source_system
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'NULL source_file',
# MAGIC            0,
# MAGIC            null_source_file
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'NULL batch_id',
# MAGIC            0,
# MAGIC            null_batch_id
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'NULL ingested_at',
# MAGIC            0,
# MAGIC            null_ingested_at
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'Duplicate LocationID',
# MAGIC            0,
# MAGIC            duplicate_location_id
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'Distinct LocationID',
# MAGIC            265,
# MAGIC            distinct_location_ids
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'Minimum LocationID',
# MAGIC            1,
# MAGIC            min_location_id
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'Maximum LocationID',
# MAGIC            265,
# MAGIC            max_location_id
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'Orphan pickup IDs',
# MAGIC            0,
# MAGIC            orphan_pickup
# MAGIC     FROM validation_results
# MAGIC
# MAGIC     UNION ALL
# MAGIC
# MAGIC     SELECT 'Orphan dropoff IDs',
# MAGIC            0,
# MAGIC            orphan_dropoff
# MAGIC     FROM validation_results
# MAGIC )
# MAGIC ORDER BY
# MAGIC     CASE check_name
# MAGIC         WHEN 'Source row count' THEN 1
# MAGIC         WHEN 'Silver row count' THEN 2
# MAGIC         WHEN 'NULL LocationID' THEN 3
# MAGIC         WHEN 'NULL Borough' THEN 4
# MAGIC         WHEN 'NULL Zone' THEN 5
# MAGIC         WHEN 'NULL service_zone' THEN 6
# MAGIC         WHEN 'NULL source_system' THEN 7
# MAGIC         WHEN 'NULL source_file' THEN 8
# MAGIC         WHEN 'NULL batch_id' THEN 9
# MAGIC         WHEN 'NULL ingested_at' THEN 10
# MAGIC         WHEN 'Duplicate LocationID' THEN 11
# MAGIC         WHEN 'Distinct LocationID' THEN 12
# MAGIC         WHEN 'Minimum LocationID' THEN 13
# MAGIC         WHEN 'Maximum LocationID' THEN 14
# MAGIC         WHEN 'Orphan pickup IDs' THEN 15
# MAGIC         WHEN 'Orphan dropoff IDs' THEN 16
# MAGIC     END;