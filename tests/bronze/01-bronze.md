# NYC Mobility Bronze Validation Tests

## Overview

These tests validate the Bronze layer of the NYC Mobility Ingestion Challenge.

Bronze preserves each source as received and adds ingestion metadata for traceability. The tests focus on ingestion integrity, source-to-Bronze reconciliation, provenance, batch idempotency, and raw-payload completeness.

```text
Source files / API response
            ↓
       01_bronze
            ↓
 Bronze validation tests
            ↓
       02_silver
```

The active Bronze scope contains the three required sources:

- NYC TLC Green Taxi
- NYC TLC Taxi Zones
- Open-Meteo Weather

NYC DOT Traffic Advisory is not part of the active Bronze quality gate. Its exploratory raw files may remain in R2 or the Databricks Volume, but they are not loaded or validated as an active Bronze source.

## Bronze Tables and Grain

| Bronze table | Grain | Approved source identifier | Expected rows |
|---|---|---|---:|
| `ftw-week-08`.`01_bronze`.`green_taxi` | One source Green Taxi record plus provenance | Three monthly Parquet files | 133,367 |
| `ftw-week-08`.`01_bronze`.`taxi_zones` | One Taxi Zone source row plus provenance | `taxi_zone_lookup.csv` | 265 |
| `ftw-week-08`.`01_bronze`.`weather_raw` | One complete raw JSON batch plus provenance | `open_meteo_2026-03-01_2026-05-31.json` | 1 |
| `ftw-week-08`.`01_bronze`.`ingestion_log` | One successful receipt per source batch | Source filename and batch ID | One receipt per batch |

Weather Bronze intentionally contains **one raw JSON record**, not 2,208 hourly rows. Expansion into hourly observations belongs in Silver.

## Approved Green Taxi Counts

| Source file | Expected Bronze rows |
|---|---:|
| `green_tripdata_2026-03.parquet` | 44,208 |
| `green_tripdata_2026-04.parquet` | 44,238 |
| `green_tripdata_2026-05.parquet` | 44,921 |
| **Total** | **133,367** |

## Test Responsibilities

Bronze tests validate:

- expected source files and batches are present;
- source and Bronze row counts match;
- required provenance fields are populated;
- the ingestion log has one successful receipt per batch;
- rerunning the same saved source does not create an additional batch;
- Taxi Zone `LocationID` is available and duplicate keys are reported;
- the Weather raw JSON is present and non-empty;
- the three required sources pass the overall Bronze gate.

Bronze tests do **not** clean or reject records based on negative amounts, unusual timestamps, trip distances, weather values, or invalid business codes. Those checks belong in Silver and its data-quality validation.

## How to Run

1. Run `02_bronze_setup.ipynb`.
2. Run `03_bronze_load.ipynb`.
3. Rerun the same saved-source load cells for the idempotency evidence.
4. Run `04_bronze_validation.ipynb`.
5. Save the Databricks query outputs or screenshots.
6. Confirm that every required condition below passes before starting Silver.

The SQL below is read-only. It does not update, delete, or repair Bronze records.

---

## Test 1: Green Taxi Row Counts by Source File

```sql
SELECT
    source_file,
    COUNT(*) AS actual_rows,
    CASE source_file
        WHEN 'green_tripdata_2026-03.parquet' THEN 44208
        WHEN 'green_tripdata_2026-04.parquet' THEN 44238
        WHEN 'green_tripdata_2026-05.parquet' THEN 44921
    END AS expected_rows,
    CASE
        WHEN COUNT(*) = CASE source_file
            WHEN 'green_tripdata_2026-03.parquet' THEN 44208
            WHEN 'green_tripdata_2026-04.parquet' THEN 44238
            WHEN 'green_tripdata_2026-05.parquet' THEN 44921
        END
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM `ftw-week-08`.`01_bronze`.`green_taxi`
WHERE source_file IN (
    'green_tripdata_2026-03.parquet',
    'green_tripdata_2026-04.parquet',
    'green_tripdata_2026-05.parquet'
)
GROUP BY source_file
ORDER BY source_file;
```

**Expected result:** Three rows, and each row has `status = PASS`.

## Test 2: Green Taxi Total Row Count

```sql
SELECT
    COUNT(*) AS actual_rows,
    133367 AS expected_rows,
    CASE
        WHEN COUNT(*) = 133367 THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM `ftw-week-08`.`01_bronze`.`green_taxi`;
```

**Expected result:** `actual_rows = 133367` and `status = PASS`.

## Test 3: No Unexpected Green Taxi Source Files

```sql
SELECT
    source_file,
    COUNT(*) AS row_count
FROM `ftw-week-08`.`01_bronze`.`green_taxi`
WHERE source_file NOT IN (
    'green_tripdata_2026-03.parquet',
    'green_tripdata_2026-04.parquet',
    'green_tripdata_2026-05.parquet'
)
   OR source_file IS NULL
GROUP BY source_file;
```

**Expected result:** Zero result rows.

This prevents an unexpected file from making the overall row count appear correct while an approved monthly batch is missing.

## Test 4: Green Taxi Provenance Completeness

```sql
SELECT
    source_file,
    batch_id,
    source_system,
    COUNT(*) AS row_count,
    COUNT_IF(
        source_file IS NULL
        OR batch_id IS NULL
        OR source_system IS NULL
        OR ingested_at IS NULL
    ) AS rows_with_missing_provenance,
    CASE
        WHEN COUNT_IF(
            source_file IS NULL
            OR batch_id IS NULL
            OR source_system IS NULL
            OR ingested_at IS NULL
        ) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM `ftw-week-08`.`01_bronze`.`green_taxi`
GROUP BY
    source_file,
    batch_id,
    source_system
ORDER BY source_file;
```

**Expected result:** Every monthly batch has `rows_with_missing_provenance = 0` and `status = PASS`.

## Test 5: Green Taxi Source-to-Bronze Reconciliation

```sql
WITH source_counts AS (
    SELECT
        'green_tripdata_2026-03.parquet' AS source_file,
        COUNT(*) AS source_row_count
    FROM read_files(
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-03.parquet',
        format => 'parquet'
    )

    UNION ALL

    SELECT
        'green_tripdata_2026-04.parquet',
        COUNT(*)
    FROM read_files(
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-04.parquet',
        format => 'parquet'
    )

    UNION ALL

    SELECT
        'green_tripdata_2026-05.parquet',
        COUNT(*)
    FROM read_files(
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/green_taxi/green_tripdata_2026-05.parquet',
        format => 'parquet'
    )
),
bronze_counts AS (
    SELECT
        source_file,
        COUNT(*) AS bronze_row_count
    FROM `ftw-week-08`.`01_bronze`.`green_taxi`
    GROUP BY source_file
)
SELECT
    source.source_file,
    source.source_row_count,
    COALESCE(bronze.bronze_row_count, 0) AS bronze_row_count,
    CASE
        WHEN source.source_row_count = COALESCE(bronze.bronze_row_count, 0)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM source_counts source
LEFT JOIN bronze_counts bronze
    ON source.source_file = bronze.source_file
ORDER BY source.source_file;
```

**Expected result:** Three rows with `source_row_count = bronze_row_count` and `status = PASS`.

## Test 6: Green Taxi Ingestion-Log Idempotency

```sql
WITH expected_batches AS (
    SELECT * FROM VALUES
        ('green_tripdata_2026-03.parquet', 'green_taxi_2026_03', 44208),
        ('green_tripdata_2026-04.parquet', 'green_taxi_2026_04', 44238),
        ('green_tripdata_2026-05.parquet', 'green_taxi_2026_05', 44921)
    AS expected(source_identifier, batch_id, expected_rows)
),
actual_logs AS (
    SELECT
        source_identifier,
        batch_id,
        COUNT(*) AS log_records,
        MAX(status) AS status,
        MAX(rows_loaded) AS rows_loaded
    FROM `ftw-week-08`.`01_bronze`.`ingestion_log`
    WHERE source_name = 'green_taxi'
    GROUP BY source_identifier, batch_id
)
SELECT
    expected.source_identifier,
    expected.batch_id,
    expected.expected_rows,
    COALESCE(actual.log_records, 0) AS log_records,
    actual.status,
    actual.rows_loaded,
    CASE
        WHEN actual.log_records = 1
         AND actual.status = 'SUCCESS'
         AND actual.rows_loaded = expected.expected_rows
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_status
FROM expected_batches expected
LEFT JOIN actual_logs actual
    ON expected.source_identifier = actual.source_identifier
   AND expected.batch_id = actual.batch_id
ORDER BY expected.source_identifier;
```

**Expected result:** Three rows with `log_records = 1`, `status = SUCCESS`, the correct `rows_loaded`, and `test_status = PASS`.

The same-file load rerun should insert zero additional Bronze rows and should not create a second successful log receipt.

---

## Test 7: Taxi Zones Source-to-Bronze Reconciliation

```sql
WITH source_count AS (
    SELECT COUNT(*) AS row_count
    FROM read_files(
        '/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/groups/week-08/group-b/source/taxi_zones/taxi_zone_lookup.csv',
        format => 'csv',
        header => true
    )
),
bronze_count AS (
    SELECT COUNT(*) AS row_count
    FROM `ftw-week-08`.`01_bronze`.`taxi_zones`
    WHERE source_file = 'taxi_zone_lookup.csv'
)
SELECT
    source.row_count AS source_row_count,
    bronze.row_count AS bronze_row_count,
    CASE
        WHEN source.row_count = 265
         AND bronze.row_count = 265
         AND source.row_count = bronze.row_count
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM source_count source
CROSS JOIN bronze_count bronze;
```

**Expected result:** Source and Bronze counts are both `265`, with `status = PASS`.

## Test 8: Taxi Zones Key and Provenance Completeness

```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT_IF(LocationID IS NULL) AS null_location_id,
    COUNT_IF(
        source_system IS NULL
        OR source_file IS NULL
        OR batch_id IS NULL
        OR ingested_at IS NULL
    ) AS rows_with_missing_provenance,
    CASE
        WHEN COUNT(*) = 265
         AND COUNT_IF(LocationID IS NULL) = 0
         AND COUNT_IF(
            source_system IS NULL
            OR source_file IS NULL
            OR batch_id IS NULL
            OR ingested_at IS NULL
         ) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM `ftw-week-08`.`01_bronze`.`taxi_zones`
WHERE source_file = 'taxi_zone_lookup.csv';
```

**Expected result:** `total_rows = 265`, both error counts are `0`, and `status = PASS`.

## Test 9: Duplicate Taxi Zone LocationIDs

```sql
SELECT
    LocationID,
    COUNT(*) AS record_count
FROM `ftw-week-08`.`01_bronze`.`taxi_zones`
WHERE source_file = 'taxi_zone_lookup.csv'
GROUP BY LocationID
HAVING COUNT(*) > 1;
```

**Expected result:** Zero result rows.

This test reports duplicates but does not remove or repair them in Bronze.

## Test 10: Taxi Zones Ingestion Receipt

```sql
SELECT
    source_identifier,
    batch_id,
    status,
    rows_loaded,
    COUNT(*) AS log_records,
    CASE
        WHEN COUNT(*) = 1
         AND status = 'SUCCESS'
         AND rows_loaded = 265
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_status
FROM `ftw-week-08`.`01_bronze`.`ingestion_log`
WHERE source_name = 'taxi_zones'
  AND source_identifier = 'taxi_zone_lookup.csv'
  AND batch_id = 'taxi_zone_lookup.csv'
GROUP BY
    source_identifier,
    batch_id,
    status,
    rows_loaded;
```

**Expected result:** One row with `status = SUCCESS`, `rows_loaded = 265`, `log_records = 1`, and `test_status = PASS`.

---

## Test 11: Weather Raw Batch and Provenance

```sql
SELECT
    COUNT(*) AS raw_batch_count,
    COUNT_IF(raw_json IS NULL OR LENGTH(raw_json) = 0)
        AS null_or_empty_raw_json,
    COUNT_IF(
        source_system IS NULL
        OR source_url IS NULL
        OR source_file IS NULL
        OR batch_id IS NULL
        OR ingested_at IS NULL
    ) AS rows_with_missing_provenance,
    CASE
        WHEN COUNT(*) = 1
         AND COUNT_IF(raw_json IS NULL OR LENGTH(raw_json) = 0) = 0
         AND COUNT_IF(
            source_system IS NULL
            OR source_url IS NULL
            OR source_file IS NULL
            OR batch_id IS NULL
            OR ingested_at IS NULL
         ) = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM `ftw-week-08`.`01_bronze`.`weather_raw`
WHERE source_file = 'open_meteo_2026-03-01_2026-05-31.json'
  AND batch_id = 'open_meteo_2026-03-01_2026-05-31.json';
```

**Expected result:** `raw_batch_count = 1`, both error counts are `0`, and `status = PASS`.

The expected Bronze count is one because the 2,208 hourly labels remain nested inside `raw_json` until Silver.

## Test 12: Weather Ingestion Receipt

```sql
SELECT
    source_identifier,
    batch_id,
    status,
    rows_loaded,
    COUNT(*) AS log_records,
    CASE
        WHEN COUNT(*) = 1
         AND status = 'SUCCESS'
         AND rows_loaded = 1
        THEN 'PASS'
        ELSE 'FAIL'
    END AS test_status
FROM `ftw-week-08`.`01_bronze`.`ingestion_log`
WHERE source_name = 'weather'
  AND source_identifier = 'open_meteo_2026-03-01_2026-05-31.json'
  AND batch_id = 'open_meteo_2026-03-01_2026-05-31.json'
GROUP BY
    source_identifier,
    batch_id,
    status,
    rows_loaded;
```

**Expected result:** One row with `status = SUCCESS`, `rows_loaded = 1`, `log_records = 1`, and `test_status = PASS`.

---

## Test 13: Overall Bronze Quality Gate

```sql
WITH checks AS (
    SELECT
        'green_taxi' AS source_name,
        COUNT(*) AS actual_rows,
        133367 AS expected_rows,
        COUNT_IF(
            source_system IS NULL
            OR source_file IS NULL
            OR batch_id IS NULL
            OR ingested_at IS NULL
        ) AS rows_with_missing_provenance
    FROM `ftw-week-08`.`01_bronze`.`green_taxi`

    UNION ALL

    SELECT
        'taxi_zones',
        COUNT(*),
        265,
        COUNT_IF(
            source_system IS NULL
            OR source_file IS NULL
            OR batch_id IS NULL
            OR ingested_at IS NULL
        )
    FROM `ftw-week-08`.`01_bronze`.`taxi_zones`
    WHERE source_file = 'taxi_zone_lookup.csv'

    UNION ALL

    SELECT
        'weather',
        COUNT(*),
        1,
        COUNT_IF(
            raw_json IS NULL
            OR source_system IS NULL
            OR source_url IS NULL
            OR source_file IS NULL
            OR batch_id IS NULL
            OR ingested_at IS NULL
        )
    FROM `ftw-week-08`.`01_bronze`.`weather_raw`
    WHERE source_file = 'open_meteo_2026-03-01_2026-05-31.json'
      AND batch_id = 'open_meteo_2026-03-01_2026-05-31.json'
)
SELECT
    source_name,
    actual_rows,
    expected_rows,
    rows_with_missing_provenance,
    CASE
        WHEN actual_rows = expected_rows
         AND rows_with_missing_provenance = 0
        THEN 'PASS'
        ELSE 'FAIL'
    END AS current_status
FROM checks
ORDER BY source_name;
```

**Expected result:** Exactly three rows—`green_taxi`, `taxi_zones`, and `weather`—and all three have `current_status = PASS`.

## Validation Matrix

| Test | Source | PASS condition | Actual result |
|---:|---|---|---|
| 1 | Green Taxi | Three approved files with their expected counts | Run in Databricks |
| 2 | Green Taxi | Total rows = 133,367 | Run in Databricks |
| 3 | Green Taxi | No unexpected source files | Run in Databricks |
| 4 | Green Taxi | No missing provenance | Run in Databricks |
| 5 | Green Taxi | Every source count equals its Bronze count | Run in Databricks |
| 6 | Green Taxi | One successful log receipt per monthly batch | Run in Databricks |
| 7 | Taxi Zones | Source rows = Bronze rows = 265 | Run in Databricks |
| 8 | Taxi Zones | No null key or missing provenance | Run in Databricks |
| 9 | Taxi Zones | No duplicate `LocationID` | Run in Databricks |
| 10 | Taxi Zones | One successful 265-row receipt | Run in Databricks |
| 11 | Weather | One non-empty raw JSON batch with complete provenance | Run in Databricks |
| 12 | Weather | One successful one-row receipt | Run in Databricks |
| 13 | Overall gate | Three required sources with `PASS` status | Run in Databricks |

## Final Validation Status

**Design status:** Complete for the active Bronze scope.

**Execution status:** Not verified by this Markdown file. Execute `04_bronze_validation.ipynb` in Databricks and save the outputs before changing the status to PASS.

Do not copy expected values into the Actual result column without execution evidence.
