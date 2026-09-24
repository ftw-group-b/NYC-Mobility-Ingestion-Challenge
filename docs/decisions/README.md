# Engineering Decisions

## 1. Preserve raw values in Bronze

Bronze keeps source values as received and adds provenance. Business cleaning rules belong in Silver, where each change is explicit and reviewable.

## 2. Retain questionable records and add flags

Rows are kept when they still contain useful information. Silver flags negative or extreme distance, invalid duration, out-of-window timestamps, and other conditions instead of silently deleting the full row.

## 3. Treat the March-May window as analytical scope

`dq_out_of_range_datetime` means outside the requested analysis period. It does not automatically mean corrupt data. Gold keeps those records and the dashboard queries filter them when answering the assigned questions.

## 4. Keep negative monetary values

Negative fares and totals can represent corrections, disputes, reversals, or source issues. They remain available for profiling and are not automatically deleted without an approved business rule.

## 5. Use local timestamp semantics

Taxi and Weather use `TIMESTAMP_NTZ` for local NYC time. Weather also keeps `timezone` and `utc_offset_seconds` so later joins do not depend on a session timezone.

## 6. Keep transformation and validation separate

Creation notebooks write tables. Validation notebooks are read-only checks. Analytics queries and analytics validation are also separate so a dashboard change does not alter the Gold model.

## 7. Use one accepted Silver row per Gold fact row

Gold does not deduplicate trips using an unproven five-column identity. `trip_key` is a deterministic technical row key, not a guaranteed real-world trip identifier.

## 8. Use an Unknown member where it has a defined meaning

Time and Weather include key `0` as Unknown. Taxi Zones reuse the official `LocationID`; unmapped values are detected through the dimension join.

## 9. Do not claim unsupported accuracy

The pipeline measures completeness, validity, uniqueness, consistency, timeliness/volume, and auditability. Accuracy is documented as limited because no independent ground-truth trip source is available.

## 10. Exclude incomplete optional Traffic Advisory data

Traffic Advisory was optional and lacked complete date coverage. The team kept the exploration evidence but removed it from the completed analytical pipeline.

## 11. Fail closed when landing provenance is incomplete

An existing raw file is reusable only when its metadata sidecar proves the
expected source system, URL, filename, byte count, and SHA-256 hash. The pipeline
does not recreate missing provenance automatically. Intentional revisions use a
new versioned filename.

## 12. Retry only operations designed for safe reruns

HTTP acquisition uses short bounded backoff for temporary failures. Databricks
task retries are limited to ingestion and Bronze load because their idempotency
guards are tested. Transformation and validation failures remain visible rather
than repeatedly consuming compute.
