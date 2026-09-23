# Data Quality Framework

The pipeline uses seven quality attributes. A PASS means the stated technical rule is satisfied; it does not mean every source value is perfect.

| Attribute | Plain-language meaning | Implemented checks |
|---|---|---|
| Completeness | Required information is present | Required keys, weather coverage, geographic mapping, and required metadata |
| Validity | Values follow agreed formats and rules | Data types, timestamp order, distances, categorical codes, and Weather codes |
| Uniqueness | Records or keys do not repeat where uniqueness is required | Ingestion receipts, dimension keys, and technical fact-row keys |
| Consistency | Related tables agree | Source-to-layer counts, Silver-to-Gold reconciliation, foreign keys, and join cardinality |
| Timeliness / Volume | Data covers the requested period and expected volume | March-May scope, hourly coverage, source-file counts, and retained-row counts |
| Auditability | Every row can be traced | `source_system`, `source_file`, `batch_id`, and ingestion metadata |
| Accuracy | Values match an independent truth | Limited: the project has no independent ground-truth trip source |

## Layer responsibilities

### Bronze

Bronze validation checks ingestion integrity and provenance:

- source-to-Bronze row preservation
- one successful receipt per source batch
- missing provenance
- repeated-file idempotency
- raw Weather payload completeness

### Silver

Silver validation checks typed and standardized data:

- required fields and timestamps
- valid categorical codes
- duplicate profiles
- source-file and batch reconciliation
- Taxi-to-Zone relationship coverage
- Weather array, timestamp, WMO-code, and coverage checks

### Gold

Gold validation checks the dimensional model:

- dimension key uniqueness
- Silver-to-Gold row and measure preservation
- fact-key behavior
- foreign-key coverage
- join cardinality
- rerun business signature

### Analytics

Analytics validation checks that each dashboard view:

- contains rows
- preserves its declared grain
- uses real 0-23 clock hours
- reconciles total trip volume with the in-scope Gold fact

## Consolidated quality gate

`tests/end_to_end/02_great_expectations_quality_gate.ipynb` combines the critical Bronze, Silver, Gold, dashboard, and analytics checks into 14 governed PASS/FAIL results. It publishes the detailed results and summary for the dashboard. Great Expectations then verifies the complete result set, required fields, unique check names, and `PASS` statuses; a failed expectation stops the job.

## Dashboard outputs

The Data Quality Dashboard uses:

- `dq_dashboard_overview`
- `dq_dashboard_check_scores`
- `dq_dashboard_dimension_scores`
- `dq_dashboard_canonical_dimensions`
- `dq_dashboard_problem_areas`
- `dq_dashboard_outside_analysis_window`
- `dq_dashboard_referential_integrity`
- `dq_dashboard_row_reconciliation`
- `dq_dashboard_zone_hotspots`
- `pipeline_quality_gate_summary`
