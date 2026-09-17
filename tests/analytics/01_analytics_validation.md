# Analytics Validation

Analytics creation and validation are separate job stages. Validation confirms:

- each dashboard view contains records;
- the declared row grain is unique;
- hour values use the real 0–23 clock convention; and
- trip volumes reconcile to the in-scope Gold fact population.

The SQL publishes `analytics_validation_results` and `analytics_validation_summary` and fails the task when any check returns `FAIL`.
