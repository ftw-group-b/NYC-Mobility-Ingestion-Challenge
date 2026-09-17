-- Databricks notebook source
-- Modular source: Silver Weather table

-- Create Silver Weather table schema with TIMESTAMP_NTZ support
-- TIMESTAMP_NTZ preserves local-hour labels without session timezone conversion
DROP TABLE IF EXISTS `ftw-week-08`.`02_silver`.`weather`;

CREATE TABLE `ftw-week-08`.`02_silver`.`weather` (
  weather_datetime TIMESTAMP_NTZ,
  latitude DOUBLE,
  longitude DOUBLE,
  timezone STRING,
  timezone_abbreviation STRING,
  utc_offset_seconds INT,
  temperature_2m DOUBLE,
  precipitation DOUBLE,
  rain DOUBLE,
  snowfall DOUBLE,
  weather_code INT,
  wind_speed_10m DOUBLE,
  source_system STRING,
  source_url STRING,
  source_file STRING,
  batch_id STRING,
  ingested_at TIMESTAMP
)
USING DELTA
TBLPROPERTIES ('delta.feature.timestampNtz' = 'supported')

-- COMMAND ----------

-- Insert Weather data by exploding and flattening the hourly JSON arrays
INSERT OVERWRITE TABLE `ftw-week-08`.`02_silver`.`weather`
WITH parsed_json AS (
  SELECT 
    from_json(raw_json, 'latitude DOUBLE, longitude DOUBLE, timezone STRING, timezone_abbreviation STRING, utc_offset_seconds INT, hourly STRUCT<time: ARRAY<STRING>, temperature_2m: ARRAY<DOUBLE>, precipitation: ARRAY<DOUBLE>, rain: ARRAY<DOUBLE>, snowfall: ARRAY<DOUBLE>, weather_code: ARRAY<INT>, wind_speed_10m: ARRAY<DOUBLE>>') AS json_data,
    source_system,
    source_url,
    source_file,
    batch_id,
    ingested_at
  FROM `ftw-week-08`.`01_bronze`.`weather_raw`
  WHERE source_file = 'open_meteo_2026-03-01_2026-05-31.json'
    AND batch_id = 'open_meteo_2026-03-01_2026-05-31.json'
),
exploded_weather AS (
  SELECT 
    -- Explode the hourly time array with position to maintain alignment
    POSEXPLODE(json_data.hourly.time) AS (hour_index, hourly_time_str),
    json_data,
    source_system,
    source_url,
    source_file,
    batch_id,
    ingested_at
  FROM parsed_json
)
SELECT
  -- Convert hourly timestamp string to TIMESTAMP_NTZ type (preserves NYC local-hour labels without session timezone conversion)
  TRY_CAST(hourly_time_str AS TIMESTAMP_NTZ) AS weather_datetime,
  
  -- Source location and timezone metadata
  json_data.latitude AS latitude,
  json_data.longitude AS longitude,
  json_data.timezone AS timezone,
  json_data.timezone_abbreviation AS timezone_abbreviation,
  json_data.utc_offset_seconds AS utc_offset_seconds,
  
  -- Extract weather measurements by position using hour_index to maintain alignment
  json_data.hourly.temperature_2m[hour_index] AS temperature_2m,
  json_data.hourly.precipitation[hour_index] AS precipitation,
  json_data.hourly.rain[hour_index] AS rain,
  json_data.hourly.snowfall[hour_index] AS snowfall,
  json_data.hourly.weather_code[hour_index] AS weather_code,
  json_data.hourly.wind_speed_10m[hour_index] AS wind_speed_10m,
  
  -- Bronze provenance columns
  source_system,
  source_url,
  source_file,
  batch_id,
  ingested_at
FROM exploded_weather
ORDER BY weather_datetime
