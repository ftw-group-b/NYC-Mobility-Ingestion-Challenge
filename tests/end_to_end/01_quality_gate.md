# Consolidated End-to-End Quality Gate

The final gate combines the critical checks needed to release dashboard data:

- Bronze-to-Silver and Silver-to-Gold row preservation;
- Silver-to-Gold retained-measure reconciliation;
- dimension and fact-key uniqueness;
- referential integrity and join cardinality;
- required lineage and populated DQ flags;
- continuous hourly Weather coverage;
- Analytics validation status; and
- explicit coverage of all seven quality attributes.

Accuracy is handled honestly: the project records that no independent trip-level ground truth is available and makes no unsupported accuracy claim.

Outputs:

- `pipeline_quality_gate_results`: one row per check;
- `pipeline_quality_gate_summary`: overall `PASS` or `FAIL`.
