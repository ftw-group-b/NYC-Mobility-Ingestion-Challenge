# Great Expectations Runbook

## Purpose

This runbook defines how Great Expectations (GX) will be introduced into the NYC Mobility Ingestion Challenge as a declarative data-quality layer.

GX will complement the repository's existing Spark/SQL validations. Existing layer notebooks remain responsible for transformation-specific checks and reconciliation. GX will provide reusable, version-controlled Expectations, structured Validation Results, and a production-oriented Checkpoint that can be executed from Databricks.

The target outcome is a repeatable quality gate:

```
Bronze/Silver/Gold tables
        ↓
GX Validation Definition(s)
        ↓
GX Checkpoint
        ↓
PASS → continue to dashboard and analytics tasks
FAIL → stop the pipeline and investigate
```

## Current project context

The repository currently uses:

- Databricks notebooks and Databricks Asset Bundles
- Delta tables in the `ftw-week-08` workspace/catalog setup
- Layered processing: ingestion → Bronze → Silver → Gold → analytics
- Gold tables: `dim_date`, `dim_time`, `dim_taxi_zone`, `dim_weather_hour`, and `fact_green_taxi_trip`
- Existing SQL/notebook validation under `tests/bronze`, `tests/silver`, `tests/gold`, and `tests/end_to_end`
- A consolidated quality gate at `tests/end_to_end/01_end_to_end_quality_gate.ipynb`
- A deployed job defined in `resources/nyc_mobility_job.yml`

GX should be added as an additional validation layer, not as a replacement for the existing quality framework.

## Assigned Senior Data Engineer deliverable

### Responsibility

The documentation owner is responsible for translating the Great Expectations assignment into an implementation-ready engineering contract for the team. This responsibility covers design, workflow alignment, operational guidance, and handoff—not the implementation of the GX code unless separately assigned.

### Documentation deliverables

This runbook addresses the documentation scope by defining:

- the role of GX in the existing Bronze → Silver → Gold architecture
- the approved first implementation scope and validation priorities
- the relationship between GX, existing Spark/SQL checks, and the consolidated quality gate
- the Databricks setup and execution sequence
- the expected CI/CD touchpoints
- the ownership boundary between documentation and implementation
- failure handling, auditability, and Definition of Done
- the handoff information required by the GX integration owner

### Current workflow alignment

The proposed GX flow is aligned with the repository's current implementation:

| Existing project component | Documentation decision |
|---|---|
| `tests/bronze`, `tests/silver`, and `tests/gold` | Continue to own layer-specific Spark/notebook validation |
| `tests/end_to_end/01_end_to_end_quality_gate.ipynb` | Remains the consolidated final quality gate |
| `resources/nyc_mobility_job.yml` | Receives the GX task only during the implementation phase |
| `.github/workflows/ci.yml` | Validates documentation and future GX assets |
| `.github/workflows/deploy-databricks.yml` | Includes future GX-related deployment paths |
| `docs/data_quality` | Stores the approved GX design and operating procedure |

### Implementation handoff

The assigned GX implementation owner will use this runbook to create and validate:

1. the pinned GX dependency
2. the GX notebook or Python module
3. the Expectation Suites
4. the Validation Definitions and Checkpoint
5. the Delta audit-result output
6. the Databricks job dependency
7. the successful and intentionally failing validation evidence

The documentation task is complete when the next engineer can implement these items without needing to rediscover the project architecture or the agreed quality rules.

### Scope boundary

This document is an implementation-ready design and operating guide. It must not claim that GX is already running in Databricks until the implementation owner provides execution evidence. After implementation, this runbook should be updated with the final notebook path, pinned version, actual suite names, job task key, audit table name, and validation evidence.

## GX terminology used in this project

| GX component | Project interpretation |
|---|---|
| Data Context | Configuration and runtime entry point for GX |
| Data Source | Spark connection used by GX |
| Data Asset | A project table or Spark DataFrame to validate |
| Batch Definition | Definition of the batch of records being validated |
| Expectation | A declarative rule about data |
| Expectation Suite | A collection of rules for one layer or quality purpose |
| Validation Definition | Association between a Batch Definition and an Expectation Suite |
| Checkpoint | Production execution unit for one or more validations |
| Validation Result | Structured output showing which Expectations passed or failed |
| Data Docs | Optional human-readable GX validation documentation |

GX's current workflow is: set up a Data Context, connect to data, define Expectations, and run Validations. In production, a Checkpoint is the preferred execution unit.

## Recommended implementation scope

### Phase 1 — Gold validation

Start with the final Gold star schema because its contracts are already approved and business-facing:

- `dim_date`
- `dim_time`
- `dim_taxi_zone`
- `dim_weather_hour`
- `fact_green_taxi_trip`

Phase 1 must validate:

- required columns and data types
- non-null primary and foreign keys
- uniqueness of dimension keys
- valid time-key mapping, including `0 = Unknown`
- valid date and timestamp ranges
- non-negative trip measures
- fact row retention and basic grain behavior
- accepted weather-coverage flags
- referential integrity between the fact and dimensions

### Phase 2 — Silver validation

Add reusable suites for:

- `green_taxi`
- `taxi_zones`
- `weather`

Phase 2 must validate:

- required source columns
- typed timestamps
- valid categorical values
- non-negative distance, fare, tip, and total measures
- weather timestamp uniqueness
- taxi-zone key coverage
- accepted out-of-range datetime handling
- source-file and batch metadata

### Phase 3 — Bronze validation

Add ingestion-focused suites for:

- source-to-Bronze row preservation
- batch receipt completeness
- provenance columns
- idempotent file loading
- raw weather payload completeness

## Step-by-step: first Databricks proof of concept

### 1. Create a working branch

Use a branch dedicated to the integration:

```bash
git checkout main
git pull origin main
git checkout -b feature/great-expectations
```

Keep the documentation, GX configuration, and notebook changes in the same pull request only when they form one coherent implementation.

### 2. Install GX in the Databricks compute used by the job

For the first proof of concept, install GX at the notebook or cluster level:

```python
%pip install "great_expectations[spark]"
```

Restart the Python process when Databricks requests it, then verify the installation:

```python
import great_expectations as gx

print(gx.__version__)
```

Pin the tested version before production deployment. Do not allow the production job to silently receive a different GX version.

Recommended production options:

1. Add the pinned package to the Databricks job's environment specification; or
2. Add a repository dependency file and install it during deployment.

The chosen option must be applied consistently to development and production clusters.

### 3. Set the project catalog and schema explicitly

Do not rely on the notebook's currently selected catalog or schema. Set them explicitly at the beginning of the GX notebook:

```python
catalog = "ftw-week-08"
silver_schema = "02_silver"
gold_schema = "03_gold"

spark.sql(f"USE CATALOG {catalog}")
```

Before validating, confirm the tables exist:

```python
spark.sql(f"SHOW TABLES IN \`{catalog}\`.{gold_schema}").display()
spark.sql(f"SHOW TABLES IN \`{catalog}\`.{silver_schema}").display()
```

If the deployed environment uses a different catalog or schema, pass those values as job parameters rather than changing the Expectations.

### 4. Read the current Delta tables as Spark DataFrames

The initial proof of concept can validate DataFrames loaded from the existing Delta tables:

```python
gold_fact = spark.table(
    f"\`{catalog}\`.{gold_schema}.fact_green_taxi_trip"
)

dim_date = spark.table(
    f"\`{catalog}\`.{gold_schema}.dim_date"
)

dim_time = spark.table(
    f"\`{catalog}\`.{gold_schema}.dim_time"
)

dim_taxi_zone = spark.table(
    f"\`{catalog}\`.{gold_schema}.dim_taxi_zone"
)

dim_weather_hour = spark.table(
    f"\`{catalog}\`.{gold_schema}.dim_weather_hour"
)
```

Use the same table names as the Gold implementation. Do not create a second copy of the Gold data just for GX.

### 5. Create or retrieve the GX Data Context

For the first interactive run:

```python
context = gx.get_context()
```

The final implementation must make the context configuration reproducible. Store GX configuration and Expectation definitions in the repository or in the approved Databricks workspace location. Do not keep the only copy in a developer's local session.

### 6. Register a Spark Data Source and Data Assets

For a DataFrame-based proof of concept, register a Spark Data Source and one Data Asset per logical validation target:

```python
data_source_name = "nyc_mobility_spark"
data_source = context.data_sources.add_spark(name=data_source_name)

fact_asset = data_source.add_dataframe_asset(
    name="gold_fact_green_taxi_trip"
)

fact_batch_definition = fact_asset.add_batch_definition_whole_dataframe(
    "current_gold_batch"
)
```

For production, keep the asset names stable. The runtime DataFrame is supplied when the validation runs, so the asset definition does not contain a hard-coded local file path.

### 7. Define the first Expectation Suite

Use business and technical rules already agreed by the team. Do not invent thresholds from a single sample run.

Recommended first Expectations for `fact_green_taxi_trip` include:

```python
suite = gx.ExpectationSuite(
    name="gold_fact_green_taxi_trip_quality"
)

suite.add_expectation(
    gx.expectations.ExpectTableColumnsToMatchSet(
        column_set=[
            # Replace this list with the final approved Gold columns.
            "trip_key",
            "pickup_date_key",
            "pickup_time_key",
            "pickup_taxi_zone_key",
            "pickup_weather_hour_key",
        ],
        exact_match=False,
    )
)

suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(
        column="trip_key"
    )
)

suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(
        column="pickup_date_key"
    )
)

suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(
        column="pickup_time_key"
    )
)

suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeBetween(
        column="pickup_time_key",
        min_value=0,
        max_value=24,
    )
)
```

The exact expectation names and parameters must be checked against the installed GX version during implementation. The code above is a starting pattern, not a substitute for running the notebook.

Add expectations in small groups and validate after each group. This makes failures attributable and prevents a large, opaque suite.

### 8. Create a Validation Definition

Associate the current Gold batch with the Gold Expectation Suite:

```python
validation_definition = gx.ValidationDefinition(
    name="validate_gold_fact_green_taxi_trip",
    data=fact_batch_definition,
    suite=suite,
)

context.validation_definitions.add(validation_definition)
```

If the installed GX version reports that the object already exists, retrieve the existing object or use the supported add-or-update operation. Avoid creating duplicate assets and suites on every notebook run.

### 9. Run the validation with the current DataFrame

```python
validation_results = validation_definition.run(
    batch_parameters={"dataframe": gold_fact}
)

print(validation_results)
```

Inspect at least:

- overall success
- expectation count
- failed expectation names
- unexpected count
- affected columns
- batch metadata
- validation timestamp

A successful notebook cell is not enough. The pipeline gate must inspect the returned GX result and fail when the result is unsuccessful.

### 10. Add cross-table checks

GX column Expectations are not sufficient for all relational rules. Keep cross-table and reconciliation rules in Spark SQL or the existing validation notebooks, then expose their results to the consolidated gate.

Examples:

- every fact date key resolves to `dim_date`
- every fact time key resolves to `dim_time`
- every taxi-zone key resolves to `dim_taxi_zone`
- weather key `0` is used only when weather coverage is intentionally unavailable
- Gold fact row count reconciles with accepted Silver trip rows
- joins do not multiply the declared fact grain

Use GX for table/column contracts and the existing Spark/SQL tests for relational and reconciliation contracts. This separation keeps each tool responsible for the checks it handles best.

### 11. Persist validation results

For production execution, do not rely only on notebook output. Persist a compact GX result record to a Delta audit table, for example:

```text
<catalog>.03_gold.gx_validation_results
```

Recommended audit columns:

| Column | Purpose |
|---|---|
| `run_id` | Identifies one pipeline run |
| `validation_name` | Identifies the suite/check |
| `layer` | Bronze, Silver, or Gold |
| `table_name` | Table validated |
| `batch_id` | Source or pipeline batch |
| `run_started_at` | Start timestamp |
| `run_finished_at` | End timestamp |
| `success` | Overall PASS/FAIL |
| `expectation_count` | Number of Expectations executed |
| `failed_expectation_count` | Number of failures |
| `unexpected_count` | Number of unexpected values |
| `result_uri` | Location of detailed result/Data Docs |
| `failure_summary` | Safe, concise failure description |

Do not store full unexpected-row payloads in logs if they may contain sensitive or unnecessarily large data. Store counts and a controlled sample only.

### 12. Add the GX task to the Databricks job

The recommended dependency placement is:

```
silver validations
        ↓
gold creation
        ↓
gold validation
        ↓
gx validation
        ↓
data-quality views + analytics
        ↓
consolidated quality gate
```

Add a task such as:

```yaml
- task_key: gx_validation
  depends_on:
    - task_key: gold_validation
  notebook_task:
    notebook_path: ../tests/data_quality/01_gx_validation.ipynb
    source: WORKSPACE
```

Then make the dashboard, analytics, or final quality-gate task depend on `gx_validation`, depending on the team's final orchestration decision.

The task must:

1. Read the same catalog and schema parameters as the pipeline.
2. Validate the current batch.
3. Persist the audit result.
4. Exit with a failure status when a critical GX validation fails.
5. Preserve the existing validation outputs for the dashboard.

### 13. Add a fail-fast quality gate

The GX task should stop the pipeline for critical failures:

```python
if not validation_results.success:
    raise RuntimeError(
        "Great Expectations quality gate failed. "
        "Review the persisted GX validation results."
    )
```

Use warning-level Expectations only for known, accepted conditions such as out-of-range datetime records that are intentionally retained and flagged. Do not downgrade a rule merely to make the job pass.

### 14. Add CI/CD checks

The existing GitHub Actions CI validates repository structure, SQL presence, Python syntax, and raw-data handling. Extend CI in a separate implementation pull request to verify:

- GX configuration files exist in the expected location
- every committed GX file is non-empty
- Expectation suite names follow the project naming convention
- no credentials or Databricks tokens are committed
- Python GX modules compile successfully
- a lightweight unit test can load the suite and verify its required Expectations

Run the full GX validation against Databricks data in the Databricks job, not against a fabricated GitHub fixture. GitHub CI should validate code and configuration; Databricks should validate the actual Delta tables.

## Recommended suite structure

Use one suite per layer/table or one suite per clear contract:

```text
gx/
├── README.md
├── expectations/
│   ├── bronze_ingestion_quality.json
│   ├── silver_green_taxi_quality.json
│   ├── silver_taxi_zones_quality.json
│   ├── silver_weather_quality.json
│   ├── gold_dimensions_quality.json
│   └── gold_fact_green_taxi_trip_quality.json
├── checkpoints/
│   └── nyc_mobility_quality.yml
└── plugins/
    └── custom_expectations/
```

Keep the repository's current validation notebooks under `tests/`. GX suite files should express reusable contracts; notebooks should handle orchestration, DataFrame loading, cross-table reconciliation, and audit persistence.

## Failure triage procedure

When GX fails:

1. Open the failed Databricks task and record the pipeline `run_id`.
2. Identify the failed suite, table, column, and expectation.
3. Compare the current batch with the previous successful run.
4. Determine whether the cause is source-data drift, transformation logic, schema drift, or an overly strict expectation.
5. Check the existing layer validation and reconciliation outputs.
6. Fix the source or transformation when the data is genuinely invalid.
7. Update the Expectation only when the business contract has changed and the change is reviewed.
8. Rerun the affected layer and GX validation.
9. Confirm the consolidated quality gate returns `PASS`.
10. Record the decision in `docs/decisions` when the accepted behavior changes.

Never delete or silently bypass a failing GX result to unblock the dashboard.

## Definition of done

Great Expectations is considered integrated when:

- the pinned GX version is reproducible in Databricks
- the Gold suite validates all final Gold tables
- Silver suites validate the three approved Silver sources
- the GX notebook runs through the Databricks Asset Bundle
- validation results are persisted with run and batch metadata
- critical failures stop downstream tasks
- existing SQL/notebook validations still run
- the final quality gate includes the GX status
- a pull request documents the new task, suites, and failure-handling behavior
- at least one successful run and one intentionally failing test are recorded as evidence

## References

- [GX Core overview](https://docs.greatexpectations.io/docs/core/introduction/gx_overview/)
- [Connect to dataframe data](https://docs.greatexpectations.io/docs/core/connect_to_data/dataframes/)
- [Great Expectations Expectation Gallery](https://greatexpectations.io/expectations/)
- [Databricks Asset Bundles](https://docs.databricks.com/aws/en/dev-tools/bundles/)
