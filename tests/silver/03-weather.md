# NYC Weather Dataset

## Overview

The weather dataset contains hourly weather observations for New York City from Open-Meteo. It includes temperature, precipitation, rain, snowfall, wind speed, and WMO weather codes.

For this project, the source JSON is loaded into the Bronze layer and transformed into a structured Silver table in Databricks.

```text
Open-Meteo JSON
      ↓
  01_bronze
      ↓
  02_silver
      ↓
   03_gold
```

The Silver layer focuses on turning the nested hourly weather data into a clean, structured table while checking coverage, completeness, and data quality.

## Dataset Grain

**Grain: 1 row = 1 hourly weather observation.**

The Silver table contains one row for each hourly timestamp from **March 1, 2026 through May 31, 2026**.

**Silver table:** `ftw-week-08`.`02_silver`.`weather`

## Source Data

The approved source batch is:

`open_meteo_2026-03-01_2026-05-31.json`

The source contains **2,208 hourly observations**, and all 2,208 were loaded into Silver.

| Check                      |               Result |
| -------------------------- | -------------------: |
| Source hourly observations |                2,208 |
| Silver rows                |                2,208 |
| Difference                 |                    0 |
| Coverage                   |                 100% |
| Date range                 | March 1-May 31, 2026 |
| Missing hourly gaps        |                    0 |
| Duplicate timestamps       |                    0 |

The Silver table covers **92 days**, from `2026-03-01 00:00:00` to `2026-05-31 23:00:00`.

## Data Quality Results

### NULL Values

No NULL values were found in any of the weather fields.

| Field              | NULL count |
| ------------------ | ---------: |
| `weather_datetime` |          0 |
| `temperature_2m`   |          0 |
| `precipitation`    |          0 |
| `rain`             |          0 |
| `snowfall`         |          0 |
| `weather_code`     |          0 |
| `wind_speed_10m`   |          0 |

### Numeric Values

The numeric fields were profiled for their observed minimum and maximum values.

| Field            | Minimum | Maximum |
| ---------------- | ------: | ------: |
| `temperature_2m` |    -9.9 |    35.8 |
| `precipitation`  |       0 |     4.5 |
| `rain`           |       0 |     4.5 |
| `snowfall`       |       0 |    0.98 |
| `wind_speed_10m` |     0.2 |    33.1 |

No negative values were found in precipitation, rain, snowfall, or wind speed.

There were also no `-999` values detected during the investigation of unusual numeric values.

### Weather Codes

All non-NULL `weather_code` values matched the documented Open-Meteo WMO weather codes.

**Invalid weather codes: 0**

## Timestamp and Coverage Validation

The Silver table was checked for missing hourly observations by comparing each timestamp with the next timestamp.

**Result: 0 missing hourly gaps.**

The expected number of hourly observations between the minimum and maximum timestamps is **2,208**, which matches the actual row count.

**Coverage: 100%.**

The source-to-Silver reconciliation also matched exactly:

| Source | Silver | Difference |
| -----: | -----: | ---------: |
|  2,208 |  2,208 |          0 |

No timestamps were found outside the requested period of **March 1, 2026 through May 31, 2026**.

## DST Inspection

March 8, 2026 was inspected separately because it falls on the DST transition date.

The source provides all 24 local-hour labels from `00:00` through `23:00`, including `02:00`.

This is recorded as an observation of the source data. It is not treated as proof that the source's DST representation is correct.

## Schema

The Silver Weather table contains:

| Column                  | Type          | Description                     |
| ----------------------- | ------------- | ------------------------------- |
| `weather_datetime`      | TIMESTAMP_NTZ | Hourly weather timestamp        |
| `latitude`              | DOUBLE        | Source location latitude        |
| `longitude`             | DOUBLE        | Source location longitude       |
| `timezone`              | STRING        | Source timezone                 |
| `timezone_abbreviation` | STRING        | Source timezone abbreviation    |
| `utc_offset_seconds`    | INT           | UTC offset in seconds           |
| `temperature_2m`        | DOUBLE        | Temperature at 2 meters in °C   |
| `precipitation`         | DOUBLE        | Total precipitation in mm       |
| `rain`                  | DOUBLE        | Rain volume in mm               |
| `snowfall`              | DOUBLE        | Snowfall in cm                  |
| `weather_code`          | INT           | WMO weather code                |
| `wind_speed_10m`        | DOUBLE        | Wind speed at 10 meters in km/h |
| `source_system`         | STRING        | Source system                   |
| `source_url`            | STRING        | Source URL                      |
| `source_file`           | STRING        | Source file                     |
| `batch_id`              | STRING        | Batch identifier                |
| `ingested_at`           | TIMESTAMP     | Ingestion timestamp             |

## Final Validation

All **20 validation checks passed**.

The validation confirms:

* 2,208 source hourly observations were loaded into Silver.
* Actual and expected hourly observations match.
* Coverage is 100%.
* There are no duplicate timestamps.
* There are no NULL weather values.
* All timestamps are within the requested period.
* There are no missing hourly gaps.
* Bronze and Silver counts match for the approved batch.
* No negative precipitation, rain, snowfall, or wind-speed values were found.
* All weather codes are valid documented WMO codes.
* The source JSON arrays are correctly aligned.
* The approved Bronze batch is present.

**Final status: PASS**
