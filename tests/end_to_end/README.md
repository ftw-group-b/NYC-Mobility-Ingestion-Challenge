# End-to-End Quality Gate

`02_great_expectations_quality_gate.ipynb` is the active final release gate. It calculates and publishes the 14 governed checks through `pipeline_quality_gate_results` and `pipeline_quality_gate_summary`.

Great Expectations validates that exactly 14 unique checks are present, required fields are populated, and every check has a `PASS` status. A failed GX expectation raises an exception and fails the Databricks task.

`01_end_to_end_quality_gate.ipynb` is retained only as a legacy SQL reference. The deployed job runs notebook `02`; no duplicate quality-gate notebook is maintained under `notebooks/`.
