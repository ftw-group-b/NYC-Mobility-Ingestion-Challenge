# Environment and deployment configuration

## Required GitHub configuration

Create both `development` and `production` GitHub environments.

| Setting | Development | Production |
|---|---|---|
| Allowed branch | Pull-request branches | `main` only |
| Required reviewers | Optional | At least one non-author maintainer |
| `DATABRICKS_HOST` | Development workspace/account target | Production workspace/account target |
| Databricks credential | Development identity | Production deployment identity |

The workflows currently read `DATABRICKS_TOKEN` for compatibility. Prefer an
environment-scoped secret over a repository-wide secret. Migrate to Databricks
workload identity federation when the team can create the service principal and
GitHub OIDC policy; those external identifiers must not be invented in code.

## Data isolation limitation

The development and production bundle deployments use different workspace
roots, but the notebooks still reference the course catalog
`ftw-week-08` and fixed schemas/Volume paths. Therefore:

- preview deployment is safe, but do **not** run its data-writing job against
  production data;
- a true multi-environment rollout requires a separate development catalog and
  Volume, plus notebook parameters for catalog, schemas, landing root, approved
  months, filenames, and NYC coordinates;
- perform that migration layer by layer with a successful preview run after
  each layer. A blind repository-wide string replacement is not safe.

This boundary is intentional for the current course deployment and prevents
the documentation from overstating environment isolation.

## Notifications and run identity

The repository does not guess email addresses, notification destination IDs,
service-principal IDs, or group names. Configure these account-owned values,
then add bundle `email_notifications` or notification destinations, `run_as`,
and resource permissions in a focused PR. Test one controlled failure before
marking alerting complete.

## Version policy

- GitHub Actions uses the immutable commit for `databricks/setup-cli` release
  `v1.10.0`.
- The installed Databricks CLI version is `1.10.0` and the bundle requires at
  least `1.10.0`.
- Great Expectations is pinned to `1.23.1` in the serverless job environment.

Upgrade one dependency at a time and require CI, preview validation, preview
deployment, and a controlled pipeline run.
