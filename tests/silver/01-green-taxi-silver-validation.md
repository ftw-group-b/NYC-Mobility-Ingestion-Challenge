# NYC Green Taxi Dataset

## Overview

The NYC Green Taxi dataset contains trip records for green taxis in New York City. Each row represents one taxi trip, with information such as pickup and drop-off times and locations, passenger count, trip distance, fares, and payment type.

For this project, the data goes through a Bronze → Silver → Gold pipeline in Databricks.

```text
NYC Green Taxi Files
        ↓
   01_bronze
        ↓
   02_silver
        ↓
    03_gold
```

The Silver layer focuses on cleaning the data, handling known data-quality issues, and keeping enough information to trace what was changed.

## Dataset Grain

**Grain: 1 row = 1 Green Taxi trip**

The Silver table keeps each trip as an individual record. It does not aggregate trips.

## Source Data

The pipeline currently processes **3 Green Taxi files** covering March to May 2026:

| Source file                      | Bronze rows | Silver rows | Status   |
| -------------------------------- | ----------: | ----------: | -------- |
| `green_tripdata_2026-03.parquet` |      44,208 |      44,208 | PASS     |
| `green_tripdata_2026-04.parquet` |      44,238 |      44,238 | PASS     |
| `green_tripdata_2026-05.parquet` |      44,921 |      44,921 | PASS     |
| **Total**                        | **133,367** | **133,367** | **PASS** |

All source rows were preserved in Silver, with no row loss during the Bronze-to-Silver transformation.

## Silver Layer

**Table:** `ftw-week-08`.`02_silver`.`green_taxi`

The Silver transformation:

* Standardizes data types
* Calculates `trip_duration_minutes`
* Preserves source and ingestion metadata
* Adds `dq_*` flags for data-quality issues
* Nullifies invalid trip-distance values
* Nullifies invalid trip-duration values
* Preserves zero trip distances
* Keeps systematic NULL patterns visible
* Removes fields that are not needed in the Silver layer

## Data Quality Results

### Trip Distance

There were **4,592 trips with zero trip distance**. These were retained and flagged rather than automatically treated as invalid.

There were **30 extreme trip distances** above the defined threshold of 1,000. All 30 were successfully nullified in the Silver `trip_distance` column.

There were **0 negative trip distances**, so no negative values required nullification.

| Check                            | Result |
| -------------------------------- | -----: |
| Zero trip distances              |  4,592 |
| Extreme trip distances flagged   |     30 |
| Extreme trip distances nullified |     30 |
| Remaining values > 1,000         |      0 |
| Negative trip distances flagged  |      0 |
| Remaining negative values        |      0 |

### Datetime and Trip Duration

The validation found **19 out-of-range datetime records**.

There was **1 invalid trip duration**, where the drop-off timestamp occurred before the pickup timestamp. The calculated duration for this record was successfully set to `NULL`.

There were no missing pickup/drop-off timestamps or LocationIDs.

| Check                                      | Result |
| ------------------------------------------ | -----: |
| Out-of-range datetime records              |     19 |
| Invalid trip durations                     |      1 |
| Invalid durations still containing a value |      0 |
| Invalid durations nullified                |      1 |
| Missing pickup datetime                    |      0 |
| Missing dropoff datetime                   |      0 |
| Missing pickup LocationID                  |      0 |
| Missing dropoff LocationID                 |      0 |

### Systematic NULL Pattern

There were **18,754 rows** where the following fields were all NULL:

* `RatecodeID`
* `congestion_surcharge`
* `passenger_count`
* `payment_type`
* `store_and_fwd_flag`
* `trip_type`

This pattern was preserved rather than treated as an automatic failure. The same 18,754 rows were observed during validation.

## Categorical Validation

### `RatecodeID`

Out of 133,367 rows:

* **18,754** were NULL
* **114,613** contained valid codes
* **0** contained invalid codes

The valid values were distributed as follows:

| Code | Description           |   Count |
| ---: | --------------------- | ------: |
|    1 | Standard rate         | 107,256 |
|    2 | JFK                   |     346 |
|    3 | Newark                |      80 |
|    4 | Nassau or Westchester |     142 |
|    5 | Negotiated fare       |   6,789 |
|    6 | Group ride            |       0 |
|   99 | Unknown               |       0 |

NULL values were counted separately as missing data and were not classified as invalid codes.

### `payment_type`

Out of 133,367 rows:

* **18,754** were NULL
* **114,613** contained valid codes
* **0** contained invalid codes

| Code | Description    |  Count |
| ---: | -------------- | -----: |
|    0 | Flex Fare Trip |      0 |
|    1 | Credit card    | 87,622 |
|    2 | Cash           | 26,050 |
|    3 | No charge      |    669 |
|    4 | Dispute        |    272 |
|    5 | Unknown        |      0 |
|    6 | Voided trip    |      0 |

## Duplicate Profiling

Exact duplicates were profiled using the original Bronze business columns.

**Result: 0 exact duplicate groups.**

This check looks for records where all selected business fields are identical. It is separate from the Silver trip grain and does not rely on a generated surrogate or hashed key.

## Final Validation

All defined Silver validation checks passed.

| Check                             | Expected |  Actual | Status |
| --------------------------------- | -------: | ------: | ------ |
| Source row count                  |  133,367 | 133,367 | PASS   |
| Source file count                 |        3 |       3 | PASS   |
| Extreme trip distances nullified  |       30 |      30 | PASS   |
| Remaining trip distance > 1000    |        0 |       0 | PASS   |
| Negative trip distances nullified |        0 |       0 | PASS   |
| Remaining negative trip distances |        0 |       0 | PASS   |
| Out-of-range datetime flagged     |       19 |      19 | PASS   |
| Invalid trip duration flagged     |        1 |       1 | PASS   |
| Invalid durations produce NULL    |        0 |       0 | PASS   |
| Systematic NULL pattern           |   18,754 |  18,754 | PASS   |
| Invalid `RatecodeID`              |        0 |       0 | PASS   |
| Invalid `payment_type`            |        0 |       0 | PASS   |
| Exact duplicate groups            |        0 |       0 | PASS   |

## Summary

The Silver `green_taxi` table contains **133,367 rows from 3 source files**, with all source rows successfully reconciled to Silver.

The validation confirms that:

* All 30 extreme trip distances were nullified.
* There are no remaining extreme or negative trip distances.
* All 19 out-of-range datetime records were correctly flagged.
* The 1 invalid trip duration was flagged and nullified.
* The 18,754-row systematic NULL pattern was preserved.
* There are no invalid `RatecodeID` or `payment_type` values.
* There are no missing pickup/drop-off timestamps or LocationIDs.
* No exact duplicate groups were found.
* All final validation checks passed.

Overall, the Silver layer keeps the original trip records while making data-quality issues explicit through the `dq_*` flags and cleaned values.
