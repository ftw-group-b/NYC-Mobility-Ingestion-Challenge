-- Databricks notebook source
-- Modular source: Gold Weather Hour dimension

CREATE OR REPLACE TABLE `ftw-week-08`.`03_gold`.dim_weather_hour
USING DELTA
AS
SELECT
    CAST(0 AS BIGINT) AS weather_hour_key,
    CAST(NULL AS TIMESTAMP_NTZ) AS weather_timestamp_local,
    CAST(NULL AS DOUBLE) AS temperature_2m,
    CAST(NULL AS DOUBLE) AS precipitation,
    CAST(NULL AS DOUBLE) AS rain,
    CAST(NULL AS DOUBLE) AS snowfall,
    CAST(NULL AS BIGINT) AS weather_code,
    CAST(NULL AS DOUBLE) AS wind_speed_10m,
    'Unknown' AS timezone,
    CAST(NULL AS DOUBLE) AS latitude,
    CAST(NULL AS DOUBLE) AS longitude,
    CAST(NULL AS BIGINT) AS utc_offset_seconds,
    'Unknown' AS source_system,
    CAST(NULL AS STRING) AS source_file,
    CAST(NULL AS STRING) AS batch_id

UNION ALL

SELECT
    CAST(DATE_FORMAT(weather_datetime, 'yyyyMMddHH') AS BIGINT),
    weather_datetime,
    temperature_2m,
    precipitation,
    rain,
    snowfall,
    weather_code,
    wind_speed_10m,
    timezone,
    latitude,
    longitude,
    utc_offset_seconds,
    source_system,
    source_file,
    batch_id
FROM `ftw-week-08`.`02_silver`.weather;
