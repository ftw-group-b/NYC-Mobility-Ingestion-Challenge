# NYC Mobility Gold Mart Validation Tests

## Overview

These tests validate the Gold dimensional model of the NYC Mobility Ingestion Challenge.

Gold organizes the accepted Silver records into reusable dimensions and one trip fact table. The tests focus on grain preservation, key integrity, source-to-target reconciliation, referential integrity, join cardinality, retained measures, and stable rerun behavior.

```text
Validated Silver tables
          ↓
       03_gold
          ↓
 Gold validation tests
          ↓
 Analytics and dashboards
```

The Gold validation scope contains:

- `dim_date`
- `dim_time`
- `dim_taxi_zone`
- `dim_weather_hour`
- `fact_green_taxi_trip`

The fact table retains one row for every accepted Silver Green Taxi record. Gold does not remove rows using an unapproved trip-identity assumption.

## Gold Tables and Grain

| Gold table | Grain | Key policy |
|---|---|---|
| `ftw-week-08`.`03_gold`.`dim_date` | One row per calendar date between the earliest and latest retained trip date | `date_key` is `yyyyMMdd` |
| `ftw-week-08`.`03_gold`.`dim_time` | One Unknown member plus one row per hour from `00:00` through `23:00` | Key `0` is Unknown; keys `1–24` map to hours `0–23` |
| `ftw-week-08`.`03_gold`.`dim_taxi_zone` | One row per trusted Silver Taxi Zone `LocationID` | `taxi_zone_key` reuses `LocationID` |
| `ftw-week-08`.`03_gold`.`dim_weather_hour` | One Unknown member plus one row per accepted Silver Weather hour | Key `0` is Unknown; observed keys use `yyyyMMddHH` |
| `ftw-week-08`.`03_gold`.`fact_green_taxi_trip` | One row per accepted Silver Green Taxi record | `trip_key` is a deterministic technical row fingerprint |

The March–May business-analysis window is applied in the analytics queries using `dq_out_of_range_datetime = FALSE`. The underlying Gold fact table remains complete so that unusual source records remain traceable.

## Key Interpretation

- `trip_key` identifies a technical fact row. It is not presented as proof of a unique real-world taxi trip.
- Pickup and drop-off date, time, and Taxi Zone columns are role-playing foreign keys.
- Trips without matching hourly Weather use the documented Unknown Weather member at `weather_hour_key = 0`.
- DQ flags and lineage fields remain available in the fact table for auditability.

## Test Responsibilities

Gold tests validate:

- all required Gold tables are available;
- every dimension follows its documented grain and key policy;
- Gold retains every accepted Silver Green Taxi record;
- retained measures reconcile between Silver and Gold;
- `trip_key` is populated and unique at the fact-row grain;
- every fact foreign key resolves to a dimension member;
- dimension joins do not multiply fact rows;
- repeated Gold builds from unchanged Silver inputs produce the same validation signature.

Gold tests do not answer the three business questions. Taxi demand, Weather behavior, and area mobility analysis remain in the separate analytics assets.

## How to Run

1. Run `notebooks/04_gold/04_gold_mart_creation.ipynb`.
2. Run `notebooks/05_validation/gold_validation/04_gold_mart_validation.ipynb`.
3. Review each result against the verified condition stated below it.
4. Retain the Databricks outputs as the validation evidence used by the end-to-end quality gate.
5. Publish the analytics and dashboard views when every required condition passes.

The SQL below is read-only. It does not create, replace, update, or delete Gold data.

---

## Test 1: Required Gold Table Inventory

```sql
SHOW TABLES IN `ftw-week-08`.`03_gold`;
```

**Verified condition:** The result contains `dim_date`, `dim_time`, `dim_taxi_zone`, `dim_weather_hour`, and `fact_green_taxi_trip`.

## Test 2: Date Dimension Integrity

```sql
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT date_key) AS unique_date_keys,
    MIN(full_date) AS minimum_date,
    MAX(full_date) AS maximum_date,

    DATEDIFF(MAX(full_date), MIN(full_date)) + 1
        AS expected_row_count,

    COUNT(*) - (
        DATEDIFF(MAX(full_date), MIN(full_date)) + 1
    ) AS missing_date_count,

    SUM(
        CASE
            WHEN date_key != CAST(DATE_FORMAT(full_date, 'yyyyMMdd') AS INT)
            THEN 1
            ELSE 0
        END
    ) AS invalid_date_key_count,

    SUM(
        CASE
            WHEN year != YEAR(full_date)
              OR quarter != QUARTER(full_date)
              OR month_number != MONTH(full_date)
              OR day_of_month != DAYOFMONTH(full_date)
              OR day_of_week != DAYOFWEEK(full_date)
              OR is_weekend != (DAYOFWEEK(full_date) IN (1, 7))
            THEN 1
            ELSE 0
        END
    ) AS invalid_date_attribute_count,

    SUM(
        CASE
            WHEN is_holiday IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS unexpected_holiday_value_count

FROM `ftw-week-08`.`03_gold`.dim_date;
```

**Verified condition:** `row_count = unique_date_keys = expected_row_count`; all four error counts are `0`.

`is_holiday` is intentionally `NULL` because no verified holiday reference is part of the approved model.

## Test 3: Retained Out-of-Analysis-Window Date Traceability

```sql
SELECT
    COUNT(*) AS affected_trip_rows,
    MIN(lpep_pickup_datetime) AS earliest_pickup_datetime,
    MAX(lpep_pickup_datetime) AS latest_pickup_datetime,
    MIN(lpep_dropoff_datetime) AS earliest_dropoff_datetime,
    MAX(lpep_dropoff_datetime) AS latest_dropoff_datetime
FROM `ftw-week-08`.`02_silver`.green_taxi
WHERE TO_DATE(lpep_pickup_datetime) = DATE '2008-12-31'
   OR TO_DATE(lpep_dropoff_datetime) = DATE '2008-12-31';
```

```sql
SELECT *
FROM `ftw-week-08`.`02_silver`.green_taxi
WHERE TO_DATE(lpep_pickup_datetime) = DATE '2008-12-31'
   OR TO_DATE(lpep_dropoff_datetime) = DATE '2008-12-31';
```

**Verified condition:** The query identifies the retained source records that extend the continuous date dimension beyond the March–May analysis window. These records remain available for auditability and are filtered only by business analytics.

## Test 4: Time Dimension Integrity

```sql
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT time_key) AS unique_time_keys,
    MIN(time_key) AS minimum_time_key,
    MAX(time_key) AS maximum_time_key,

    SUM(
        CASE
            WHEN time_key = 0
             AND hour_24 IS NULL
             AND hour_label = 'Unknown'
             AND day_period = 'Unknown'
            THEN 0
            WHEN time_key = 0 THEN 1
            ELSE 0
        END
    ) AS invalid_unknown_row_count,

    SUM(
        CASE
            WHEN time_key BETWEEN 1 AND 24
             AND hour_24 = time_key - 1
            THEN 0
            WHEN time_key BETWEEN 1 AND 24 THEN 1
            ELSE 0
        END
    ) AS invalid_hour_mapping_count

FROM `ftw-week-08`.`03_gold`.dim_time;
```

**Verified condition:** `row_count = 25`, `unique_time_keys = 25`, the key range is `0–24`, and both error counts are `0`.

## Test 5: Taxi Zone Dimension Integrity

```sql
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT taxi_zone_key) AS unique_taxi_zone_keys,

    COUNT(*) - COUNT(DISTINCT taxi_zone_key)
        AS duplicate_taxi_zone_key_count,

    SUM(
        CASE
            WHEN taxi_zone_key IS NULL THEN 1
            ELSE 0
        END
    ) AS null_taxi_zone_key_count,

    SUM(
        CASE
            WHEN location_id IS NULL THEN 1
            ELSE 0
        END
    ) AS null_location_id_count,

    SUM(
        CASE
            WHEN taxi_zone_key != location_id THEN 1
            ELSE 0
        END
    ) AS key_reference_mismatch_count

FROM `ftw-week-08`.`03_gold`.dim_taxi_zone;
```

**Verified condition:** `row_count = unique_taxi_zone_keys`; all duplicate, null, and key-mismatch counts are `0`.

## Test 6: Weather Dimension Reconciliation and Integrity

```sql
WITH source_summary AS (
    SELECT
        COUNT(*) AS source_row_count,
        COUNT(DISTINCT weather_datetime) AS source_unique_weather_hours
    FROM `ftw-week-08`.`02_silver`.weather
),
gold_actual_weather AS (
    SELECT
        COUNT(*) AS gold_actual_row_count,
        COUNT(DISTINCT weather_hour_key) AS unique_weather_hour_keys,
        COUNT(DISTINCT weather_timestamp_local) AS unique_weather_timestamps,
        COUNT_IF(weather_hour_key IS NULL) AS null_weather_hour_key_count,
        COUNT_IF(weather_timestamp_local IS NULL) AS null_weather_timestamp_count,
        COUNT_IF(
            weather_hour_key != CAST(
                DATE_FORMAT(weather_timestamp_local, 'yyyyMMddHH') AS BIGINT
            )
        ) AS invalid_weather_key_mapping_count
    FROM `ftw-week-08`.`03_gold`.dim_weather_hour
    WHERE weather_hour_key != 0
),
unknown_member AS (
    SELECT COUNT(*) AS unknown_member_count
    FROM `ftw-week-08`.`03_gold`.dim_weather_hour
    WHERE weather_hour_key = 0
)
SELECT
    s.source_row_count,
    s.source_unique_weather_hours,
    g.gold_actual_row_count,
    g.unique_weather_hour_keys,
    g.unique_weather_timestamps,
    g.gold_actual_row_count - s.source_row_count AS actual_row_count_difference,
    g.null_weather_hour_key_count,
    g.null_weather_timestamp_count,
    g.invalid_weather_key_mapping_count,
    u.unknown_member_count
FROM source_summary AS s
CROSS JOIN gold_actual_weather AS g
CROSS JOIN unknown_member AS u;
```

**Verified condition:** Accepted Silver and observed Gold Weather counts match; the row-count difference and all error counts are `0`; observed keys and timestamps are unique; `unknown_member_count = 1`.

## Test 7: Fact-to-Silver Row and Measure Reconciliation

```sql
WITH silver_summary AS (
    SELECT
        COUNT(*) AS row_count,
        SUM(trip_distance) AS trip_distance,
        SUM(trip_duration_minutes) AS trip_duration_minutes,
        SUM(fare_amount) AS fare_amount,
        SUM(extra) AS extra,
        SUM(mta_tax) AS mta_tax,
        SUM(tip_amount) AS tip_amount,
        SUM(tolls_amount) AS tolls_amount,
        SUM(improvement_surcharge) AS improvement_surcharge,
        SUM(congestion_surcharge) AS congestion_surcharge,
        SUM(cbd_congestion_fee) AS cbd_congestion_fee,
        SUM(total_amount) AS total_amount
    FROM `ftw-week-08`.`02_silver`.green_taxi
),
gold_summary AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT trip_key) AS unique_trip_keys,
        COUNT_IF(trip_key IS NULL) AS null_trip_keys,
        SUM(trip_count) AS trip_count,
        SUM(trip_distance) AS trip_distance,
        SUM(trip_duration_minutes) AS trip_duration_minutes,
        SUM(fare_amount) AS fare_amount,
        SUM(extra) AS extra,
        SUM(mta_tax) AS mta_tax,
        SUM(tip_amount) AS tip_amount,
        SUM(tolls_amount) AS tolls_amount,
        SUM(improvement_surcharge) AS improvement_surcharge,
        SUM(congestion_surcharge) AS congestion_surcharge,
        SUM(cbd_congestion_fee) AS cbd_congestion_fee,
        SUM(total_amount) AS total_amount
    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
)
SELECT
    s.row_count AS silver_rows,
    g.row_count AS gold_rows,
    g.row_count - s.row_count AS row_difference,
    g.unique_trip_keys,
    g.row_count - g.unique_trip_keys AS duplicate_trip_key_count,
    g.null_trip_keys,
    g.trip_count - s.row_count AS trip_count_difference,
    ROUND(g.trip_distance - s.trip_distance, 6) AS distance_difference,
    ROUND(g.trip_duration_minutes - s.trip_duration_minutes, 6) AS duration_difference,
    ROUND(g.fare_amount - s.fare_amount, 6) AS fare_difference,
    ROUND(g.extra - s.extra, 6) AS extra_difference,
    ROUND(g.mta_tax - s.mta_tax, 6) AS mta_tax_difference,
    ROUND(g.tip_amount - s.tip_amount, 6) AS tip_difference,
    ROUND(g.tolls_amount - s.tolls_amount, 6) AS tolls_difference,
    ROUND(
        g.improvement_surcharge - s.improvement_surcharge, 6
    ) AS improvement_surcharge_difference,
    ROUND(
        g.congestion_surcharge - s.congestion_surcharge, 6
    ) AS congestion_surcharge_difference,
    ROUND(
        g.cbd_congestion_fee - s.cbd_congestion_fee, 6
    ) AS cbd_congestion_fee_difference,
    ROUND(g.total_amount - s.total_amount, 6) AS total_amount_difference
FROM silver_summary AS s
CROSS JOIN gold_summary AS g;
```

**Verified condition:** Silver and Gold row counts match; `trip_count_difference = 0`; fact keys are unique and non-null; every retained-measure difference is `0` at six-decimal tolerance.

## Test 8: Fact Grain and Technical Row Key

```sql
SELECT
    COUNT(*) AS row_count,
    COUNT(DISTINCT trip_key) AS unique_trip_keys,
    COUNT(*) - COUNT(DISTINCT trip_key) AS duplicate_trip_count,
    SUM(
        CASE
            WHEN trip_key IS NULL THEN 1
            ELSE 0
        END
    ) AS null_trip_key_count
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip;
```

**Verified condition:** `row_count = unique_trip_keys`; `duplicate_trip_count = 0`; `null_trip_key_count = 0`.

## Test 9: Candidate Trip-Identity Investigation

```sql
WITH candidate_groups AS (
    SELECT
        VendorID,
        lpep_pickup_datetime,
        lpep_dropoff_datetime,
        PULocationID,
        DOLocationID,

        COUNT(*) AS candidate_group_rows,

        COUNT(DISTINCT trip_distance) AS distinct_trip_distances,
        COUNT(DISTINCT passenger_count) AS distinct_passenger_counts,
        COUNT(DISTINCT fare_amount) AS distinct_fare_amounts,
        COUNT(DISTINCT tip_amount) AS distinct_tip_amounts,
        COUNT(DISTINCT total_amount) AS distinct_total_amounts

    FROM `ftw-week-08`.`02_silver`.green_taxi

    GROUP BY
        VendorID,
        lpep_pickup_datetime,
        lpep_dropoff_datetime,
        PULocationID,
        DOLocationID

    HAVING COUNT(*) > 1
)

SELECT
    COUNT(*) AS candidate_group_count,
    SUM(candidate_group_rows) AS candidate_row_count,
    SUM(candidate_group_rows - 1) AS potential_rows_removed_if_deduplicated,

    SUM(
        CASE
            WHEN distinct_trip_distances > 1
              OR distinct_passenger_counts > 1
              OR distinct_fare_amounts > 1
              OR distinct_tip_amounts > 1
              OR distinct_total_amounts > 1
            THEN 1
            ELSE 0
        END
    ) AS groups_with_different_measures

FROM candidate_groups;
```

**Verified condition:** The output profiles the risk of treating five shared fields as a business key. It does not remove records. Groups with different measures remain distinct accepted fact rows.

## Test 10: Deterministic Full-Record Fingerprint

```sql
WITH proposed_identity AS (
    SELECT
        xxhash64(
            VendorID,
            lpep_pickup_datetime,
            lpep_dropoff_datetime,
            store_and_fwd_flag,
            RatecodeID,
            PULocationID,
            DOLocationID,
            passenger_count,
            trip_distance,
            trip_duration_minutes,
            fare_amount,
            extra,
            mta_tax,
            tip_amount,
            tolls_amount,
            improvement_surcharge,
            total_amount,
            payment_type,
            trip_type,
            congestion_surcharge,
            cbd_congestion_fee,
            source_file
        ) AS proposed_record_key
    FROM `ftw-week-08`.`02_silver`.green_taxi
)

SELECT
    COUNT(*) AS silver_row_count,
    COUNT(DISTINCT proposed_record_key) AS unique_proposed_record_keys,
    COUNT(*) - COUNT(DISTINCT proposed_record_key)
        AS exact_duplicate_record_count,
    COUNT_IF(proposed_record_key IS NULL)
        AS null_proposed_record_key_count
FROM proposed_identity;
```

**Verified condition:** `silver_row_count = unique_proposed_record_keys`; both duplicate and null proposed-key counts are `0`.

This fingerprint is a technical fact-row key, not proof of unique real-world trip identity.

## Test 11: Fact-to-Dimension Join Cardinality

```sql
SELECT
    COUNT(*) AS fact_row_count,
    COUNT(DISTINCT f.trip_key) AS fact_unique_trip_keys,
    COUNT(*) - COUNT(DISTINCT f.trip_key)
        AS duplicate_rows_after_dimension_joins
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS pickup_date
    ON f.pickup_date_key = pickup_date.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS dropoff_date
    ON f.dropoff_date_key = dropoff_date.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS pickup_time
    ON f.pickup_time_key = pickup_time.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS dropoff_time
    ON f.dropoff_time_key = dropoff_time.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS pickup_zone
    ON f.pickup_taxi_zone_key = pickup_zone.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS dropoff_zone
    ON f.dropoff_taxi_zone_key = dropoff_zone.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS weather
    ON f.pickup_weather_hour_key = weather.weather_hour_key;
```

**Verified condition:** `fact_row_count = fact_unique_trip_keys`; `duplicate_rows_after_dimension_joins = 0`.

## Test 12: Fact Foreign-Key Relationships

```sql
SELECT
    SUM(CASE WHEN d_pickup.date_key IS NULL THEN 1 ELSE 0 END)
        AS missing_pickup_date_keys,
    SUM(CASE WHEN d_dropoff.date_key IS NULL THEN 1 ELSE 0 END)
        AS missing_dropoff_date_keys,
    SUM(CASE WHEN t_pickup.time_key IS NULL THEN 1 ELSE 0 END)
        AS missing_pickup_time_keys,
    SUM(CASE WHEN t_dropoff.time_key IS NULL THEN 1 ELSE 0 END)
        AS missing_dropoff_time_keys,
    SUM(CASE WHEN z_pickup.taxi_zone_key IS NULL THEN 1 ELSE 0 END)
        AS missing_pickup_zone_keys,
    SUM(CASE WHEN z_dropoff.taxi_zone_key IS NULL THEN 1 ELSE 0 END)
        AS missing_dropoff_zone_keys,
    SUM(CASE WHEN w.weather_hour_key IS NULL THEN 1 ELSE 0 END)
        AS missing_weather_keys
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_pickup
    ON f.pickup_date_key = d_pickup.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_dropoff
    ON f.dropoff_date_key = d_dropoff.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_pickup
    ON f.pickup_time_key = t_pickup.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_dropoff
    ON f.dropoff_time_key = t_dropoff.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_pickup
    ON f.pickup_taxi_zone_key = z_pickup.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_dropoff
    ON f.dropoff_taxi_zone_key = z_dropoff.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w
    ON f.pickup_weather_hour_key = w.weather_hour_key;
```

**Verified condition:** Every missing-key count is `0`. Trips without observed Weather match the valid Unknown member rather than creating a broken foreign key.

## Test 13: Unexpected Missing Weather References

```sql
SELECT
    f.pickup_weather_hour_key,
    f.pickup_datetime,
    f.dropoff_datetime,
    f.pickup_taxi_zone_key,
    f.dropoff_taxi_zone_key,
    f.source_file,
    f.dq_out_of_range_datetime
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w
    ON f.pickup_weather_hour_key = w.weather_hour_key
WHERE w.weather_hour_key IS NULL
ORDER BY f.pickup_datetime;
```

**Verified condition:** Zero result rows. Valid Unknown-member assignments are included in `dim_weather_hour` and therefore do not appear here.

## Test 14: Stable Gold Rerun Signature

```sql
SELECT
    COUNT(*) AS fact_row_count,
    COUNT(DISTINCT trip_key) AS unique_trip_keys,
    SUM(trip_count) AS total_trip_count,
    ROUND(SUM(trip_distance), 6) AS total_trip_distance,
    ROUND(SUM(trip_duration_minutes), 6) AS total_trip_duration_minutes,
    ROUND(SUM(total_amount), 6) AS total_amount,
    SUM(CAST(xxhash64(
        trip_key,
        pickup_date_key,
        dropoff_date_key,
        pickup_time_key,
        dropoff_time_key,
        pickup_taxi_zone_key,
        dropoff_taxi_zone_key,
        pickup_weather_hour_key,
        total_amount,
        source_file
    ) AS DECIMAL(38, 0))) AS business_row_checksum
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip;
```

**Verified condition:** Rebuilding Gold from unchanged Silver inputs produces the same row count, unique-key count, measure totals, and business-row checksum. Operational timestamps are excluded from this signature.

## Validation Matrix

| Test | Gold object | PASS condition | Evidence |
|---:|---|---|---|
| 1 | Gold schema | All five required tables are present | Databricks query output |
| 2 | `dim_date` | Continuous dates, unique keys, correct attributes, no unexpected holiday values | Databricks query output |
| 3 | Silver-to-Date context | Retained out-of-window records remain traceable | Databricks query output |
| 4 | `dim_time` | 25 unique members with correct Unknown and hour mapping | Databricks query output |
| 5 | `dim_taxi_zone` | Unique, non-null keys that match trusted `LocationID` values | Databricks query output |
| 6 | `dim_weather_hour` | Silver reconciliation, unique observed hours, and exactly one Unknown member | Databricks query output |
| 7 | `fact_green_taxi_trip` | Silver and Gold rows and retained measures reconcile | Databricks query output |
| 8 | Fact grain | Technical row keys are unique and non-null | Databricks query output |
| 9 | Trip identity profiling | Candidate groups are measured without deleting accepted records | Databricks query output |
| 10 | Proposed fingerprint | One unique, non-null fingerprint per accepted Silver row | Databricks query output |
| 11 | Dimension joins | Joins preserve one fact row per technical key | Databricks query output |
| 12 | Fact foreign keys | Every role-playing foreign key resolves | Databricks query output |
| 13 | Weather references | No unresolved Weather foreign keys | Databricks query output |
| 14 | Gold rerun | Unchanged Silver input produces the same validation signature | Databricks query output |

## Data-Quality Attributes Covered

| Attribute | Gold evidence |
|---|---|
| Completeness | Silver-to-Gold row reconciliation, retained measures, complete foreign-key coverage |
| Uniqueness | Dimension keys, fact technical keys, Weather hours, rerun fingerprint |
| Validity | Date attributes, time mapping, key derivation, Unknown-member policies |
| Consistency | Silver and Gold measures reconcile; fact keys agree with dimension keys |
| Accuracy | Gold derivations are compared with their accepted Silver values and documented formulas |
| Auditability | Source file, batch ID, DQ flags, retained unusual records, and diagnostic queries remain available |
| Timeliness | Hourly Weather keys and trip date/time roles preserve the accepted event timestamps |

## Analytics Separation

Business-question analysis remains in three standalone analytics assets:

- `taxi_demand.sql` — demand by day, hour, and zone;
- `weather_behavior.sql` — Weather and trip behavior;
- `area_mobility_patterns.sql` — pickup/drop-off activity and area opportunities.

This separation prevents the Gold build and technical validation from duplicating dashboard business logic.

## Final Gold Mart Validation Status

The Gold validation documentation is created and aligned with the implemented dimensional model and `04_gold_mart_validation.ipynb`.

The verified conditions cover dimension grain, technical-key integrity, Silver-to-Gold reconciliation, retained measures, foreign keys, join cardinality, auditability, and stable rerun behavior. The Databricks query outputs provide the evidence for each PASS decision without inserting unsupported numerical results into this document.
