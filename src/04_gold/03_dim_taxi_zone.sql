-- Databricks notebook source
-- Modular source: Gold Taxi Zone dimension

CREATE OR REPLACE TABLE `ftw-week-08`.`03_gold`.dim_taxi_zone
USING DELTA
AS
SELECT
    CAST(LocationID AS INT) AS taxi_zone_key,
    CAST(LocationID AS INT) AS location_id,
    Borough AS borough,
    Zone AS zone_name,
    service_zone
FROM `ftw-week-08`.`02_silver`.taxi_zones;
