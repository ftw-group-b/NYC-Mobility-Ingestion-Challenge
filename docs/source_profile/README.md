# Source Profiles

## Green Taxi

- Provider: NYC Taxi and Limousine Commission
- Format: monthly Parquet
- Required files: March, April, and May 2026
- Source grain: one trip record
- Important fields: pickup/drop-off timestamps, location IDs, distance, fare components, payment type, passenger count, and vendor ID
- Ingestion behavior: one guarded load per source file

Negative financial amounts are retained for analysis. They are not automatically removed because the source documentation does not prove that every negative amount is an error.

## Taxi Zones

- Provider: NYC Taxi and Limousine Commission
- Format: CSV
- Source grain: one row per `LocationID`
- Purpose: translates pickup and drop-off LocationIDs into Borough, Zone, and service-zone labels

LocationIDs 264 and 265 are valid lookup members. Geographic completeness is checked through the actual Taxi Zone dimension join instead of hardcoded exclusion rules.

## Weather

- Provider: Open-Meteo historical API
- Format: JSON
- Source grain in Bronze: one complete API payload
- Source grain in Silver: one source-provided local-hour label
- Coverage: March-May 2026
- Time handling: local NYC labels stored as `TIMESTAMP_NTZ`, with timezone and UTC-offset metadata retained

All hourly arrays are checked for equal length before expansion. Weather codes are checked against the documented Open-Meteo WMO values.

## Traffic Advisory exploration

NYC DOT Traffic Advisory HTML/PDF files were explored and retained as source-research evidence. The available records did not provide complete March-May 2026 coverage, so this optional source is excluded from the completed Bronze, Silver, Gold, and dashboard pipeline.
