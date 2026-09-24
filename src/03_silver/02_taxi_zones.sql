-- Databricks notebook source
-- Modular source: Silver Taxi Zones table (incremental)

-- Schema-only creation: run once to initialize table if it does not exist
CREATE TABLE IF NOT EXISTS `ftw-week-08`.`02_silver`.`taxi_zones` (
  LocationID INT,
  Borough STRING,
  Zone STRING,
  service_zone STRING,
  source_system STRING,
  source_file STRING,
  batch_id STRING,
  ingested_at TIMESTAMP
)
USING DELTA;

-- COMMAND ----------

-- Idempotent upsert: update existing records and insert new ones on LocationID
MERGE INTO `ftw-week-08`.`02_silver`.`taxi_zones` AS target
USING (
  SELECT
    CAST(LocationID AS INT) AS LocationID,
    CAST(Borough AS STRING) AS Borough,
    CAST(Zone AS STRING) AS Zone,
    CAST(service_zone AS STRING) AS service_zone,
    source_system,
    source_file,
    batch_id,
    ingested_at
  FROM `ftw-week-08`.`01_bronze`.`taxi_zones`
) AS source
ON target.LocationID = source.LocationID
WHEN MATCHED THEN
  UPDATE SET
    Borough = source.Borough,
    Zone = source.Zone,
    service_zone = source.service_zone,
    ingested_at = source.ingested_at
WHEN NOT MATCHED THEN
  INSERT (LocationID, Borough, Zone, service_zone, source_system, source_file, batch_id, ingested_at)
  VALUES (source.LocationID, source.Borough, source.Zone, source.service_zone, source.source_system, source.source_file, source.batch_id, source.ingested_at);
