# Data Quality Process

This document comprehensively documents our Data Quality (DQ) process, checks, thresholds, and decisions based on the implementation found in the project's source code. 

**Note on Results:** The actual row counts and DQ scores reflect the current state of the Databricks `ftw-week-08` SQL Warehouse data and are included in this document!

---

## 1. Overview

The Data Quality process ensures the integrity, validity, and reliability of the NYC Mobility data pipeline. It runs against the Gold layer, acting as the final validation before data is consumed by business dashboards. 

The standard data flow is:
`Source → Bronze → Silver → Gold → Data Quality → Dashboard`

---

## 2. DQ Process Overview

The data quality and cleaning process is distributed across the pipeline layers:

* **Bronze:** Raw data is ingested as-is. Minimal processing is done, but essential auditability metadata (`ingested_at`, `source_file`, `batch_id`, `source_system`) is appended.
* **Silver:** Basic data cleaning, type conversion, and derivation occur here.
  * Timestamps are truncated to hour (`pickup_hour`, `dropoff_hour`).
  * `trip_duration_minutes` is derived.
  * Payment types are mapped to descriptions.
  * Invalid measures (e.g., `trip_distance > 1000` or `< 0`) are NULLified.
  * Boolean data quality flags (`dq_zero_trip_distance`, `dq_out_of_range_datetime`, etc.) are attached to each row based on raw values. 
* **Gold:** Constructs the dimensional model (facts and dimensions). 
  * Generates surrogate technical keys (`trip_key`).
  * Joins Silver taxi data with dimensional keys (`dim_date`, `dim_time`, `dim_taxi_zone`, `dim_weather_hour`).
  * Adds dimensional DQ flags (e.g., `dq_missing_weather_coverage`).
* **Data Quality (Dashboard Views):** A series of analytical SQL views (in `src/06_data_quality/`) aggregate the DQ flags from Gold tables into scores, percentages, and lists of problematic rows, serving as the source for the Data Quality Dashboard.

Instead of dropping failed records, the pipeline generally retains them and marks them using boolean `dq_*` flags. This allows analytics users to explicitly filter them out or study anomalies without data loss.

---

## 3. Bronze → Silver → Gold Row Counts and Decisions

| Table | Bronze Rows | Silver Rows | Gold Rows | Row Change | Reason / Decisions Made |
| :--- | ---: | ---: | ---: | ---: | :--- |
| `green_taxi` | 133,367 | 133,367 | 133,367 | 0 | Rows are preserved from Bronze to Silver. Validations flag data rather than dropping it. |
| `taxi_zones` | 265 | 265 | 265 | 0 | Rows are preserved exactly as-is. |
| `weather` | 1 (Raw) | 2,208 | 2,209 | +1 (Silver->Gold) | Exploded in Silver. Gold layer explicitly adds one 'Unknown' member. |

**Important Note on Data Retention & Analytics Filtering:** 
As shown above, the Gold layer retains all 133,367 `green_taxi` records and carries DQ flags downstream rather than dropping data. It is up to the Analytics layer to apply question-specific filters. For example, 19 records with an out-of-range datetime are flagged and subsequently excluded in analytics, leaving 133,348 valid records for date-sensitive queries. Other flagged records (like the 4,592 trips with zero distance) remain available unless the specific metric requires their exclusion. (See *Section 17* for a detailed breakdown).

---

## 4. Data Quality Dimensions

The project explicitly implements seven Data Quality dimensions defined in `05_canonical_dimensions.sql`:

1. **COMPLETENESS**
   * **Checks:** Unknown/unmapped pickup zones, missing weather coverage.
   * **Why it matters:** Ensures analytical queries have required contextual attributes.
   * **Action:** Flagged via `dq_missing_weather_coverage` and NULL dimension keys. Rows are retained.
2. **VALIDITY**
   * **Checks:** Zero trip distance, extreme trip distance (>1000), negative trip distance, invalid trip duration (dropoff < pickup), out-of-range datetime.
   * **Why it matters:** Identifies logically impossible or statistically extreme anomalies.
   * **Action:** Flagged via boolean `dq_*` columns. Values might be NULLified in Silver (e.g., extreme distances), but rows are retained.
3. **UNIQUENESS**
   * **Checks:** Null trip keys, duplicate trip keys.
   * **Why it matters:** Prevents double-counting in business analytics.
   * **Action:** Flagged during DQ aggregation (`dq_null_trip_key`, `dq_duplicate_trip_key`).
4. **CONSISTENCY**
   * **Checks:** Referential integrity (Fact to Dimension foreign keys).
   * **Why it matters:** Ensures fact data aligns precisely with dimensional data without duplicating rows during joins.
   * **Action:** Monitored separately via the `dq_dashboard_referential_integrity` view.
5. **TIMELINESS / VOLUME**
   * **Checks:** Silver-to-Gold row counts match; hourly weather sequence is continuous.
   * **Action:** Monitored separately via the `dq_dashboard_row_reconciliation` view.
6. **AUDITABILITY**
   * **Checks:** Missing source lineage (`source_system`, `source_file`, `batch_id`).
   * **Why it matters:** Ensures all records can be traced back to their origin.
   * **Action:** Flagged in summary tables if lineage columns are NULL.
7. **ACCURACY**
   * **Status:** NOT MEASURED.
   * **Why:** Documented as "N/A - no external ground truth for reconciliation."

---

## 5. DQ Checks

| DQ Dimension | Table | Column(s) | Check | Logic / Condition | Target Flag Value | Actual Failed Rows | Action / Decision |
| :--- | :--- | :--- | :--- | :--- | :--- | ---: | :--- |
| VALIDITY | `green_taxi` | `trip_distance` | Zero trip distance | `trip_distance = 0` | `FALSE` | 4,592 | Flagged (`dq_zero_trip_distance`) |
| VALIDITY | `green_taxi` | `trip_distance` | Extreme trip distance | `trip_distance > 1000` | `FALSE` | 30 | Flagged; distance set to NULL |
| VALIDITY | `green_taxi` | `trip_distance` | Negative trip distance | `trip_distance < 0` | `FALSE` | 0 | Flagged; distance set to NULL |
| VALIDITY | `green_taxi` | `lpep_*_datetime` | Invalid trip duration | `dropoff < pickup` | `FALSE` | 1 | Flagged (`dq_invalid_trip_duration`) |
| TIMELINESS/VOLUME | `green_taxi` | `lpep_*_datetime` | Out of range datetime | Not between 2026-03-01 and 2026-06-01 | `FALSE` | 19 | Flagged, but excluded from standard DQ scores |
| COMPLETENESS | `fact_green_taxi_trip` | `weather_hour_key` | Missing weather | `w.weather_hour_key IS NULL` | `FALSE` | 11 | Flagged (`dq_missing_weather_coverage`) |
| COMPLETENESS | `fact_green_taxi_trip` | `pickup_taxi_zone_key` | Unmapped pickup zone | `z.taxi_zone_key IS NULL` | `FALSE` | 0 | Flagged in summary queries |
| UNIQUENESS | `fact_green_taxi_trip` | `trip_key` | Null trip key | `trip_key IS NULL` | `FALSE` | 0 | Flagged in summary queries |
| UNIQUENESS | `fact_green_taxi_trip` | `trip_key` | Duplicate trip key | `COUNT(*) OVER (PARTITION BY trip_key) > 1` | `FALSE` | 0 | Flagged in summary queries |
| AUDITABILITY | `fact_green_taxi_trip` | `source_file`, `batch_id` | Missing lineage | Any lineage column IS NULL | `FALSE` | 0 | Flagged in summary queries |
| CONSISTENCY | `fact_green_taxi_trip` | `*_date_key`, `*_time_key` etc. | Orphaned Foreign Keys | LEFT JOIN matches IS NULL | `FALSE` | 0 | Counted in `referential_integrity` view |

---

## 6. ACTUAL DQ RESULTS

The actual numbers below were pulled directly from the Databricks SQL Warehouse.

### Overall DQ Results Summary

*Total Rows: 133,367*

| DQ Dimension | Checks | Failed / Flagged Rows | Flagged % |
| :--- | ---: | ---: | ---: |
| VALIDITY & TIMELINESS | 5 | 4,642 | 3.480% |
| COMPLETENESS | 2 | 11 | 0.008% |
| UNIQUENESS | 2 | 0 | 0.000% |
| AUDITABILITY | 1 | 0 | 0.000% |

### Individual DQ Results

**Completeness Results**
| Table | Column | Total Rows | NULL / Missing Rows | NULL / Missing % |
| :--- | :--- | ---: | ---: | ---: |
| `fact_green_taxi_trip` | `weather_hour_key` | 133,367 | 11 | 0.008% |
| `fact_green_taxi_trip` | `pickup_taxi_zone_key` | 133,367 | 0 | 0.000% |

**Validity Results**
| Table | Column | Total Rows | Invalid Rows | Invalid % |
| :--- | :--- | ---: | ---: | ---: |
| `green_taxi` | `trip_distance` (Zero) | 133,367 | 4,592 | 3.443% |
| `green_taxi` | `trip_distance` (Extreme) | 133,367 | 30 | 0.022% |
| `green_taxi` | `trip_duration` (Invalid) | 133,367 | 1 | 0.001% |
| `green_taxi` | `trip_distance` (Negative) | 133,367 | 0 | 0.000% |

**Uniqueness Results**
| Table | Key / Column(s) | Total Rows | Duplicate Rows | Duplicate % |
| :--- | :--- | ---: | ---: | ---: |
| `fact_green_taxi_trip` | `trip_key` | 133,367 | 0 | 0.000% |

**Referential Integrity Results**
| Fact Table | Foreign Key | Dimension Table | Total Rows | Orphaned / Missing FK Rows | Failure % |
| :--- | :--- | :--- | ---: | ---: | ---: |
| `fact_green_taxi_trip` | All Dimension Keys | Multiple | 133,367 | 0 | 0.000% |

---

## 7. Completeness Checks and Results
Completeness checks evaluate if critical relationships can be mapped. 

- **Unmapped Zone:** If the `PULocationID` doesn't map to a valid record in `dim_taxi_zone`.
**Decision:** Incomplete records are retained and flagged. The records are still useful for overall volume metrics, even if weather correlation isn't possible.
*(Actual result: 11 rows failed due to missing weather. 0 rows failed unmapped pickup zone.)*

## 8. Validity Checks and Results
Validity checks use hard thresholds on continuous variables:
- **Zero trip distance:** Evaluated as `trip_distance = 0`.
- **Negative trip distance:** `trip_distance < 0`.
- **Extreme trip distance:** `trip_distance > 1000`.
- **Invalid duration:** `lpep_dropoff_datetime < lpep_pickup_datetime`.
- **Out of range datetime:** Outside the 2026-03-01 to 2026-06-01 window. *(Note: This is tracked as an Analytics filter, not a strict Validity failure).*   
**Decision:** All are flagged. Notably, for negative and extreme distance, the *value itself* is cast to NULL in Silver to prevent it from skewing mathematical averages, while the row is retained. 
*(Actual result: Zero distance is the most common failure (4,592 rows). Extreme distance occurred 30 times. Out of range datetime occurred 19 times. Negative distance occurred 0 times.)*

## 9. Uniqueness / Duplicate Checks and Results
A deterministic hash key (`trip_key`) is generated using `xxhash64()` across all dimensions and measures in the Gold layer. While it acts as a technical surrogate key, it is deterministic based on row content and does not natively guarantee uniqueness (e.g., if two perfectly identical source rows exist, they will produce duplicate hashes).
Uniqueness is validated by checking:
- Null keys: `COUNT_IF(trip_key IS NULL)`
- Duplicates: `HAVING COUNT(*) > 1` on the `trip_key`.
**Decision:** Duplicates are flagged via window functions and aggregated, but they are not dropped in this layer.
*(Actual result: 0 duplicate or null trip keys were found.)*

## 10. Referential Integrity and Results
The `dq_dashboard_referential_integrity` view checks if `fact_green_taxi_trip` accurately maps to its dimensions (`dim_date`, `dim_time`, `dim_taxi_zone`, `dim_weather_hour`).
It sums the occurrence of NULL keys on the right side of a `LEFT JOIN`.  
**Decision:** The check looks for `has_orphaned_fk`. If a single row is missing multiple foreign keys (e.g. missing both weather and zone), `rows_with_orphaned_fk` in the `dq_dashboard_overview` view correctly counts it as **one unique row** using an `OR` condition, avoiding overcounting.
*(Actual result: 100% referential integrity achieved; 0 orphaned FKs found.)*

---

## 11. DQ Scoring / Aggregation and Actual Results

The dashboard computes high-level scores in `02_overview.sql` and `04_dimension_scores.sql`.

* **rows_with_any_dq_flag:** Counts unique rows that tripped at least one DQ flag (Uses `OR` logic). 
* **clean_rows:** `total_rows - rows_with_any_dq_flag`
* **clean_row_pct:** `(clean_rows / total_rows) * 100.0`
* **flagged_pct (per check):** `(flagged_rows / total_rows) * 100.0`

**Important Note on Aggregation:** 
In `03_check_scores.sql`, a single row that has both an invalid distance *and* an invalid duration will be counted twice (once in each check bucket). However, in `02_overview.sql`, the `rows_with_any_dq_flag` metric correctly counts that row only once. 

| Metric | Formula | Actual Value | Meaning |
| :--- | :--- | ---: | :--- |
| `total_rows` | `COUNT(*)` | 133,367 | Total rows evaluated |
| `rows_with_any_dq_flag` | `COUNT_IF(has_any_dq_flag)` | 4,642 | Unique rows failing standard checks. |
| `outside_analysis_window`| `COUNT_IF(dq_out_of_range...)`| 19 | Separately tracked filter flags |
| `clean_row_pct` | `(clean_rows / total_rows) * 100.0` | 96.53% | Percentage of perfectly clean rows |

---

## 12. Thresholds and Decisions

| Decision / Rule | Value | Where Applied | Actual Result | Reason | Effect on Data |
| :--- | ---: | :--- | ---: | :--- | :--- |
| Extreme Distance | `> 1000` | Silver (`green_taxi`) | 30 Flags | Identifies statistically extreme anomalies | Value set to NULL, row flagged |
| Negative Distance | `< 0` | Silver (`green_taxi`) | 0 Flags | Identifies logically impossible physics | Value set to NULL, row flagged |
| Date Window | Mar-May 2026 | Silver (`green_taxi`) | 19 Flags | Focus business analytics on the governed period | Flagged as `dq_out_of_range_datetime` |
| Retain failed rows | N/A | Silver / Gold | 4,642 Flags | Prevent silent data loss and allow anomaly analytics | Invalid rows still appear in tables |

*(Reasoning is derived directly from SQL logic and architecture READMEs).*

---

## 13. Data Cleaning vs Data Quality

**Data Transformation / Cleaning (Bronze → Silver):**
* Type casting (Strings to Timestamps).
* Calculation of derived variables (Trip duration).
* Imputation/Sanitization (Setting negative distances to NULL).

**Data Quality Validation (Gold → DQ Views):**
* Measuring referential integrity (Orphaned FKs).
* Dimension scoring (Grouping flags into COMPLETENESS, VALIDITY, etc.).
* Aggregating summary KPIs (Total Clean rows).

Row counts should remain constant from Bronze to Silver to Gold (1:1 preservation), as cleaning handles invalid data by NULLifying fields or flagging them, not by dropping rows.

---

## 14. Dashboard Metrics and Actual Dashboard Results

The final Data Quality Dashboard pulls from these specialized views:

| Dashboard Metric | Source DQ Table / Query | Actual Result | What It Tells Us |
| :--- | :--- | :--- | :--- |
| Executive Clean % | `dq_dashboard_overview` | **96.53%** | Overall pipeline health |
| Worst Dimension | `dq_dashboard_dimension_scores` | **VALIDITY & TIMELINESS** (4,642 flags) | Which DQ category is most problematic |
| Top Hotspot | `dq_dashboard_zone_hotspots` | **Unknown Zone** (64.6% flagged) | Which geographic areas have the dirtiest data |
| Row Reconciliation | `dq_dashboard_row_reconciliation` | **100.0%** (133k/133k) | Ensures no data was lost during modeling |

---

## 15. Known Issues / Limitations

* **Accuracy is unverified:** The pipeline has no independent, external ground truth (e.g. an external ledger) to verify if the trips actually happened.
* **Multiple flags per row:** When evaluating `03_check_scores.sql`, a single bad row can inflate the sum of `flagged_rows` across different checks. Analysts must rely on `dq_dashboard_overview` for accurate unique failed row counts.

---

## 16. End-to-End Example

**Scenario:** A taxi trip is recorded with a `trip_distance` of 2500 miles.
1. **Bronze:** Record ingested as is.
2. **Silver Transformation:** The query `01_green_taxi.sql` checks the distance. Since `2500 > 1000`, the `trip_distance` column is cast to `NULL`. Simultaneously, the `dq_extreme_trip_distance` boolean column is set to `TRUE`.
3. **Gold Fact:** The trip is joined with dimensions. `dq_extreme_trip_distance` remains `TRUE`.
4. **Data Quality:** The `dq_dashboard_check_scores` view aggregates this, adding `1` to the `extreme_dist` count under the `VALIDITY` dimension. 
5. **Dashboard Metric:** The Executive Overview reduces the overall `clean_row_pct` because this row triggered an `OR` condition flag. 

---

## 17. Gold Layer Data Retention Details

Total Gold: 133,367
* Out-of-range datetime: 19 → excluded in analytics → 133,348
* Zero trip distance: 4,592 → retained unless the specific analysis excludes them
* Extreme trip distance: 30 → value set to NULL, record retained
* Negative trip distance: 0
* Invalid trip duration: 1 → duration set to NULL, record retained

Gold retains all records and carries DQ flags downstream. Analytics applies question-specific filters, such as excluding the 19 records outside the analysis date range. Other flagged records remain available unless the specific metric requires their exclusion.

---

## 18. Summary

The Data Quality process for the NYC Mobility pipeline is designed to maximize data retention while providing high visibility into data anomalies. Instead of aggressively filtering out bad records at the Silver layer, the pipeline flags them using a robust suite of dimensional boolean indicators. 

Validation is categorized into standard dimensions (Completeness, Validity, Uniqueness, Consistency, Timeliness/Volume, and Auditability) and surfaced through modular SQL views. These views track both granular, check-level failures and unique row-level impact, ensuring that the downstream dashboards provide an accurate representation of data health. 
