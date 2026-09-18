# NYC Taxi Zones Dataset

## Overview

The Taxi Zones dataset provides the lookup information used to identify NYC taxi pickup and drop-off locations. Each row represents one taxi zone and contains the `LocationID`, borough, zone name, and service zone.

For this project, the dataset is processed through the Bronze → Silver → Gold pipeline in Databricks.

```text
Taxi Zones Source
       ↓
   01_bronze
       ↓
   02_silver
       ↓
    03_gold
```

The Silver layer focuses on preserving the source data, maintaining unique location identifiers, validating categorical values, and adding lineage metadata for downstream use.

## Dataset Grain

**Grain: 1 row = 1 taxi zone identified by `LocationID`.**

The Silver table contains one record for each `LocationID` from 1 to 265.

## Silver Table

**Table:** `ftw-week-08`.`02_silver`.`taxi_zones`

The Silver transformation:

* Standardizes the taxi zone columns
* Preserves `LocationID`, `Borough`, `Zone`, and `service_zone`
* Preserves lineage metadata: `source_system`, `source_file`, `batch_id`, and `ingested_at`
* Maintains one record per `LocationID`
* Provides the lookup table used to validate Green Taxi pickup and drop-off locations

## Validation Results

The Silver table contains **265 rows**, matching the Bronze source exactly.

| Check                         | Expected | Actual | Status |
| ----------------------------- | -------: | -----: | :----: |
| Bronze rows                   |      265 |    265 |  PASS  |
| Silver rows                   |      265 |    265 |  PASS  |
| Distinct LocationIDs          |      265 |    265 |  PASS  |
| Minimum LocationID            |        1 |      1 |  PASS  |
| Maximum LocationID            |      265 |    265 |  PASS  |
| Duplicate LocationIDs         |        0 |      0 |  PASS  |
| Invalid `service_zone` values |        0 |      0 |  PASS  |

The `service_zone` domain was validated against the source-defined categorical values:

* `Boro Zone`
* `Yellow Zone`
* `Airports`
* `EWR`
* `N/A`

No unexpected `service_zone` values were found.

`N/A` is retained as a source-defined categorical value rather than being treated as a NULL. In particular, LocationIDs 264 and 265 contain source-defined special records.

### NULL Values

No NULL values were found in the business columns or lineage metadata.

| Field           | NULL values |
| --------------- | ----------: |
| `LocationID`    |           0 |
| `Borough`       |           0 |
| `Zone`          |           0 |
| `service_zone`  |           0 |
| `source_system` |           0 |
| `source_file`   |           0 |
| `batch_id`      |           0 |
| `ingested_at`   |           0 |

The categorical values were also profiled to distinguish valid source-defined values from actual missing data. No NULL values were found.

### Categorical Values

The observed `service_zone` values are:

| `service_zone` | Row count |
| -------------- | --------: |
| `Boro Zone`    |       205 |
| `Yellow Zone`  |        55 |
| `Airports`     |         2 |
| `EWR`          |         1 |
| `N/A`          |         2 |

The Taxi Zones source also contains special categorical values such as `EWR`, `Unknown`, `N/A`, and `Outside of NYC`. These are preserved because they are source-defined values, not automatically interpreted as missing data.

### Referential Integrity

The Silver Taxi Zones table was checked against the Silver Green Taxi table.

Every non-NULL pickup and drop-off `LocationID` in Green Taxi matched a corresponding `LocationID` in Taxi Zones.

| Check                | Orphan rows |
| -------------------- | ----------: |
| Pickup LocationIDs   |           0 |
| Drop-off LocationIDs |           0 |

This means there are no unmatched pickup or drop-off location references in the current Silver Green Taxi data.

## Final Validation

All **17 validation checks passed**:

* Bronze and Silver row counts match at 265 rows.
* No NULL values were found in the business columns.
* All lineage metadata is present.
* `LocationID` is unique.
* All 265 expected `LocationID` values are present.
* The `LocationID` range is 1–265.
* No invalid `service_zone` values were found.
* No orphan Green Taxi pickup LocationIDs were found.
* No orphan Green Taxi drop-off LocationIDs were found.

The Silver Taxi Zones table is therefore ready to serve as the location lookup dimension for the downstream Green Taxi Gold layer.
