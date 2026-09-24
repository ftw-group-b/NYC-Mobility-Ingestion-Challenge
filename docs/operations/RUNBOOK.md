# NYC Mobility Operations Runbook

## What to monitor

- **Execution:** the latest Databricks job run and every task duration.
- **Failures:** failed or timed-out tasks and the first useful error message.
- **Freshness:** expected source months and dashboard update time.
- **Data quality:** all 14 governed checks and the final GX result.

The job permits one concurrent run, has a two-hour run timeout, and applies
short retries only to the rerun-safe ingestion and Bronze-load tasks.

## Normal deployment and run

1. Open a pull request and wait for `NYC Mobility CI Quality Gates` and the
   development preview to pass.
2. Obtain the required code-owner approval.
3. Merge to `main`; the production workflow validates and deploys the bundle.
4. Manually run `CD - Deploy NYC Mobility to Databricks` with
   `run_pipeline=true` when a data refresh is intended.
5. Verify the Databricks run reaches `consolidated_quality_gate` and that GX
   reports success.

## Safe recovery

Use a Databricks repair run for the failed task and its downstream tasks when
the upstream successful outputs are still valid. Start a full run when source
files, schemas, or transformation logic changed.

| Failure | First checks | Recovery |
|---|---|---|
| Ingestion HTTP 429/5xx | Source availability and final retry error | Retry after the provider recovers; the helper already uses bounded backoff. |
| Missing or mismatched metadata | Raw file, sidecar, SHA-256, source URL | Do not overwrite automatically. Quarantine the pair, verify provenance, then use a new versioned filename or restore the trusted pair. |
| Bronze duplicate batch | `source_file` in the ingestion log and target table | Repair from `bronze_load`; an accepted file returns `IDEMPOTENT_SKIP`. |
| Source schema drift | New/missing columns and source release notes | Update source SQL, notebook, tests, and documentation together; do not enable silent schema evolution. |
| Silver/Gold validation | First failing assertion and affected rows | Correct the upstream transform and repair from that task. |
| GX quality gate | Failed expectation and `pipeline_quality_gate_results` | Fix the governed check or its upstream data; do not bypass the gate. |
| Deployment validation | Bundle error, target, and workflow environment | Correct bundle configuration in a PR and rerun preview before production. |

## Evidence to keep

Record the Git commit, workflow URL, Databricks run URL, failed task, error
message, affected source file/month, recovery action, and final successful run.

## Escalation and ownership

Repository ownership is declared in `.github/CODEOWNERS`. GitHub production
environment reviewers own deployment approval, while the Databricks job owner
owns runtime recovery.

Failure email notifications use the environment-scoped
`DATABRICKS_ALERT_EMAIL` variable. A controlled development failure confirmed
successful delivery. With `alert_on_last_attempt` enabled, a retryable task
sends an alert only when its final attempt fails.
