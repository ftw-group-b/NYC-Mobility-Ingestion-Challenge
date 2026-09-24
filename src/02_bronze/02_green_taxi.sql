-- Databricks notebook source
-- Modular source: Bronze Green Taxi table and guarded monthly loads

-- create the bronze table structure
-- preserve all source columns and add ingestion metadata only

CREATE TABLE IF NOT EXISTS `ftw-week-08`.`01_bronze`.`green_taxi`
USING DELTA
AS

SELECT
    src.*,
    CAST(NULL AS STRING) AS source_system,
    CAST(NULL AS STRING) AS source_file,
    CAST(NULL AS STRING) AS batch_id,
    CAST(NULL AS TIMESTAMP) AS ingested_at

FROM read_files(
    '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-03.parquet',
    format => 'parquet'
) AS src

WHERE 1 = 0;

-- COMMAND ----------

-- check the target first so an already loaded file is not read or analyzed again

BEGIN
  IF NOT EXISTS (
      SELECT 1
      FROM `ftw-week-08`.`01_bronze`.`green_taxi`
      WHERE source_file = 'green_tripdata_2026-03.parquet'
  ) THEN
    INSERT INTO `ftw-week-08`.`01_bronze`.`green_taxi` BY NAME
    SELECT
        src.*,
        'nyc_tlc' AS source_system,
        'green_tripdata_2026-03.parquet' AS source_file,
        'green_taxi_2026_03' AS batch_id,
        CURRENT_TIMESTAMP() AS ingested_at
    FROM read_files(
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-03.parquet',
        format => 'parquet',
        schemaEvolutionMode => 'none'
    ) AS src;
  END IF;
END;

-- COMMAND ----------

BEGIN
  IF NOT EXISTS (
      SELECT 1
      FROM `ftw-week-08`.`01_bronze`.`green_taxi`
      WHERE source_file = 'green_tripdata_2026-04.parquet'
  ) THEN
    INSERT INTO `ftw-week-08`.`01_bronze`.`green_taxi` BY NAME
    SELECT
        src.*,
        'nyc_tlc' AS source_system,
        'green_tripdata_2026-04.parquet' AS source_file,
        'green_taxi_2026_04' AS batch_id,
        CURRENT_TIMESTAMP() AS ingested_at
    FROM read_files(
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-04.parquet',
        format => 'parquet',
        schemaEvolutionMode => 'none'
    ) AS src;
  END IF;
END;

-- COMMAND ----------

BEGIN
  IF NOT EXISTS (
      SELECT 1
      FROM `ftw-week-08`.`01_bronze`.`green_taxi`
      WHERE source_file = 'green_tripdata_2026-05.parquet'
  ) THEN
    INSERT INTO `ftw-week-08`.`01_bronze`.`green_taxi` BY NAME
    SELECT
        src.*,
        'nyc_tlc' AS source_system,
        'green_tripdata_2026-05.parquet' AS source_file,
        'green_taxi_2026_05' AS batch_id,
        CURRENT_TIMESTAMP() AS ingested_at
    FROM read_files(
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-05.parquet',
        format => 'parquet',
        schemaEvolutionMode => 'none'
    ) AS src;
  END IF;
END;
