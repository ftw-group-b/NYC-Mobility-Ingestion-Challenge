-- Databricks notebook source
-- Modular source: Bronze Taxi Zones table and guarded load

-- create the taxi zones bronze structure without loading rows

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01_bronze`.`taxi_zones`
USING DELTA
AS
SELECT
    src.*,
    CAST(NULL AS STRING) AS source_system,
    CAST(NULL AS STRING) AS source_file,
    CAST(NULL AS STRING) AS batch_id,
    CAST(NULL AS TIMESTAMP) AS ingested_at
FROM read_files(
    '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/taxi_zones/taxi_zone_lookup.csv',
    format => 'csv',
    header => true
) AS src
WHERE 1 = 0;

-- COMMAND ----------

-- load the exact taxi zone file only once

INSERT INTO `ftw-week-08`.`01_bronze`.`taxi_zones`
SELECT
    src.*,
    'nyc_tlc' AS source_system,
    'taxi_zone_lookup.csv' AS source_file,
    'taxi_zone_lookup.csv' AS batch_id,
    CURRENT_TIMESTAMP() AS ingested_at
FROM read_files(
    '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/taxi_zones/taxi_zone_lookup.csv',
    format => 'csv',
    header => true
) AS src
WHERE NOT EXISTS (
    SELECT 1
    FROM `ftw-week-08`.`01_bronze`.`taxi_zones`
    WHERE source_file = 'taxi_zone_lookup.csv'
);
