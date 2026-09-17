-- Databricks notebook source
-- Modular source: Silver Taxi Zones table

CREATE OR REPLACE TABLE `ftw-week-08`.`02_silver`.`taxi_zones`
USING DELTA
AS
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
