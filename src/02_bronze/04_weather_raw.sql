-- Databricks notebook source
-- Modular source: Bronze Weather raw table and guarded payload load

-- preserve one complete raw json payload per weather batch

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01_bronze`.`weather_raw` (
    raw_json     STRING,
    source_system STRING,
    source_url    STRING,
    source_file   STRING,
    batch_id      STRING,
    ingested_at   TIMESTAMP
)
USING DELTA;

-- COMMAND ----------

-- load one complete raw json record for the exact saved weather batch

INSERT INTO `ftw-week-08`.`01_bronze`.`weather_raw`
SELECT
    CAST(src.content AS STRING) AS raw_json,
    'open_meteo' AS source_system,
    'https://archive-api.open-meteo.com/v1/archive?latitude=40.7128&longitude=-74.006&start_date=2026-03-01&end_date=2026-05-31&hourly=temperature_2m,precipitation,rain,snowfall,weather_code,wind_speed_10m&timezone=America%2FNew_York' AS source_url,
    'open_meteo_2026-03-01_2026-05-31.json' AS source_file,
    'open_meteo_2026-03-01_2026-05-31.json' AS batch_id,
    CURRENT_TIMESTAMP() AS ingested_at
FROM read_files(
    '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/weather/open_meteo_2026-03-01_2026-05-31.json',
    format => 'binaryFile'
) AS src
WHERE NOT EXISTS (
    SELECT 1
    FROM `ftw-week-08`.`01_bronze`.`weather_raw`
    WHERE source_file = 'open_meteo_2026-03-01_2026-05-31.json'
);
