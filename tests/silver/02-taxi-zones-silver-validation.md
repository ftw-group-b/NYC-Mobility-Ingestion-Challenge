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

The Silver layer focuses on preserving the source data, keeping the location identifiers unique, and adding lineage metadata for downstream use.

## Dataset Grain

**Grain: 1 row = 1 unique taxi zone identified by `LocationID`.**

The Silver table contains one record for each LocationID from 1 to 265.

## Silver Table

**Table:** `ftw-week-08`.`02_silver`.`taxi_zones`

The Silver transformation:

* Standardizes the taxi zone columns
* Preserves `LocationID`, `Borough`, `Zone`, and `service_zone`
* Preserves lineage metadata: `source_system`, `source_file`, `batch_id`, and `ingested_at`
* Keeps one record per `LocationID`
* Provides the lookup table used to validate Green Taxi pickup and drop-off locations

## Validation Results

The Silver table contains **265 rows**, matching the Bronze source exactly.

| Check                 | Result |
| --------------------- | -----: |
| Bronze rows           |    265 |
| Silver rows           |    265 |
| Distinct LocationIDs  |    265 |
| Minimum LocationID    |      1 |
| Maximum LocationID    |    265 |
| Duplicate LocationIDs |      0 |

### NULL and Blank Values

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

There were also **0 blank or space-only values** in `Borough`, `Zone`, or `service_zone`.

### Referential Integrity

The Silver Taxi Zones table was also checked against the Silver Green Taxi table.

Every non-NULL pickup and drop-off `LocationID` in Green Taxi matched a corresponding `LocationID` in Taxi Zones.

| Check                | Orphan rows |
| -------------------- | ----------: |
| Pickup LocationIDs   |           0 |
| Drop-off LocationIDs |           0 |

This means there are no unmatched pickup or drop-off location references in the current Silver Green Taxi data.

## Final Validation

All **16 validation checks passed**:

* Bronze and Silver row counts match.
* All business columns are complete.
* All lineage metadata is present.
* `LocationID` is unique.
* All 265 expected LocationIDs are present.
* The LocationID range is 1–265.
* No blank or space-only descriptions were found.
* All Green Taxi pickup LocationIDs have a matching Taxi Zone.
* All Green Taxi drop-off LocationIDs have a matching Taxi Zone.

The Silver Taxi Zones table is therefore ready to serve as the location lookup dimension for the downstream Green Taxi Gold layer.
