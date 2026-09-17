-- Databricks notebook source
-- Modular source: Bronze ingestion log table and successful batch receipts

-- operational log used to track which source batches were processed

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01_bronze`.`ingestion_log` (
    source_system     STRING,
    source_name       STRING,
    source_type       STRING,
    source_identifier STRING,
    source_path       STRING,
    batch_id          STRING,
    status            STRING,
    rows_loaded       BIGINT,
    ingested_at       TIMESTAMP
)
USING DELTA;

-- COMMAND ----------

-- record the successfully validated march batch

MERGE INTO `ftw-week-08`.`01_bronze`.`ingestion_log` AS target

USING (
    SELECT
        'nyc_tlc' AS source_system,
        'green_taxi' AS source_name,
        'parquet' AS source_type,
        'green_tripdata_2026-03.parquet' AS source_identifier,
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-03.parquet' AS source_path,
        'green_taxi_2026_03' AS batch_id,
        'SUCCESS' AS status,
        COUNT(*) AS rows_loaded,
        MAX(ingested_at) AS ingested_at
    FROM `ftw-week-08`.`01_bronze`.`green_taxi`
    WHERE source_file = 'green_tripdata_2026-03.parquet'
) AS incoming

ON target.source_identifier = incoming.source_identifier
AND target.batch_id = incoming.batch_id

WHEN NOT MATCHED THEN
INSERT (
    source_system,
    source_name,
    source_type,
    source_identifier,
    source_path,
    batch_id,
    status,
    rows_loaded,
    ingested_at
)
VALUES (
    incoming.source_system,
    incoming.source_name,
    incoming.source_type,
    incoming.source_identifier,
    incoming.source_path,
    incoming.batch_id,
    incoming.status,
    incoming.rows_loaded,
    incoming.ingested_at
);

-- COMMAND ----------

-- record the successfully validated april batch

MERGE INTO `ftw-week-08`.`01_bronze`.`ingestion_log` AS target

USING (
    SELECT
        'nyc_tlc' AS source_system,
        'green_taxi' AS source_name,
        'parquet' AS source_type,
        'green_tripdata_2026-04.parquet' AS source_identifier,
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-04.parquet' AS source_path,
        'green_taxi_2026_04' AS batch_id,
        'SUCCESS' AS status,
        COUNT(*) AS rows_loaded,
        MAX(ingested_at) AS ingested_at
    FROM `ftw-week-08`.`01_bronze`.`green_taxi`
    WHERE source_file = 'green_tripdata_2026-04.parquet'
) AS incoming

ON target.source_identifier = incoming.source_identifier
AND target.batch_id = incoming.batch_id

WHEN NOT MATCHED THEN
INSERT (
    source_system,
    source_name,
    source_type,
    source_identifier,
    source_path,
    batch_id,
    status,
    rows_loaded,
    ingested_at
)
VALUES (
    incoming.source_system,
    incoming.source_name,
    incoming.source_type,
    incoming.source_identifier,
    incoming.source_path,
    incoming.batch_id,
    incoming.status,
    incoming.rows_loaded,
    incoming.ingested_at
);

-- COMMAND ----------

-- record the successfully validated may batch

MERGE INTO `ftw-week-08`.`01_bronze`.`ingestion_log` AS target

USING (
    SELECT
        'nyc_tlc' AS source_system,
        'green_taxi' AS source_name,
        'parquet' AS source_type,
        'green_tripdata_2026-05.parquet' AS source_identifier,
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-05.parquet' AS source_path,
        'green_taxi_2026_05' AS batch_id,
        'SUCCESS' AS status,
        COUNT(*) AS rows_loaded,
        MAX(ingested_at) AS ingested_at
    FROM `ftw-week-08`.`01_bronze`.`green_taxi`
    WHERE source_file = 'green_tripdata_2026-05.parquet'
) AS incoming

ON target.source_identifier = incoming.source_identifier
AND target.batch_id = incoming.batch_id

WHEN NOT MATCHED THEN
INSERT (
    source_system,
    source_name,
    source_type,
    source_identifier,
    source_path,
    batch_id,
    status,
    rows_loaded,
    ingested_at
)
VALUES (
    incoming.source_system,
    incoming.source_name,
    incoming.source_type,
    incoming.source_identifier,
    incoming.source_path,
    incoming.batch_id,
    incoming.status,
    incoming.rows_loaded,
    incoming.ingested_at
);

-- COMMAND ----------

-- record taxi zones only after its expected row count is present

MERGE INTO `ftw-week-08`.`01_bronze`.`ingestion_log` AS target
USING (
    SELECT
        'nyc_tlc' AS source_system,
        'taxi_zones' AS source_name,
        'csv' AS source_type,
        'taxi_zone_lookup.csv' AS source_identifier,
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/taxi_zones/taxi_zone_lookup.csv' AS source_path,
        'taxi_zone_lookup.csv' AS batch_id,
        'SUCCESS' AS status,
        COUNT(*) AS rows_loaded,
        MAX(ingested_at) AS ingested_at
    FROM `ftw-week-08`.`01_bronze`.`taxi_zones`
    WHERE source_file = 'taxi_zone_lookup.csv'
    HAVING COUNT(*) = 265
) AS incoming
ON target.source_identifier = incoming.source_identifier
AND target.batch_id = incoming.batch_id
WHEN NOT MATCHED THEN
INSERT (
    source_system,
    source_name,
    source_type,
    source_identifier,
    source_path,
    batch_id,
    status,
    rows_loaded,
    ingested_at
)
VALUES (
    incoming.source_system,
    incoming.source_name,
    incoming.source_type,
    incoming.source_identifier,
    incoming.source_path,
    incoming.batch_id,
    incoming.status,
    incoming.rows_loaded,
    incoming.ingested_at
);

-- COMMAND ----------

-- record weather only after its raw batch is complete

MERGE INTO `ftw-week-08`.`01_bronze`.`ingestion_log` AS target
USING (
    SELECT
        'open_meteo' AS source_system,
        'weather' AS source_name,
        'json' AS source_type,
        'open_meteo_2026-03-01_2026-05-31.json' AS source_identifier,
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/weather/open_meteo_2026-03-01_2026-05-31.json' AS source_path,
        'open_meteo_2026-03-01_2026-05-31.json' AS batch_id,
        'SUCCESS' AS status,
        COUNT(*) AS rows_loaded,
        MAX(ingested_at) AS ingested_at
    FROM `ftw-week-08`.`01_bronze`.`weather_raw`
    WHERE source_file = 'open_meteo_2026-03-01_2026-05-31.json'
    HAVING COUNT(*) = 1
       AND SUM(CASE WHEN raw_json IS NULL OR LENGTH(raw_json) = 0 THEN 1 ELSE 0 END) = 0
) AS incoming
ON target.source_identifier = incoming.source_identifier
AND target.batch_id = incoming.batch_id
WHEN NOT MATCHED THEN
INSERT (
    source_system,
    source_name,
    source_type,
    source_identifier,
    source_path,
    batch_id,
    status,
    rows_loaded,
    ingested_at
)
VALUES (
    incoming.source_system,
    incoming.source_name,
    incoming.source_type,
    incoming.source_identifier,
    incoming.source_path,
    incoming.batch_id,
    incoming.status,
    incoming.rows_loaded,
    incoming.ingested_at
);
