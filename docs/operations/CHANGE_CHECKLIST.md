# Change-impact checklist

Use this checklist whenever one pipeline asset changes.

- [ ] Update the modular implementation under `src/`.
- [ ] Update its compiled Databricks notebook under `notebooks/`.
- [ ] Update focused unit/alignment tests under `tests/unit/`.
- [ ] Update layer validation or the GX contract when behavior changes.
- [ ] Update job dependencies, paths, timeouts, or environment dependencies.
- [ ] Update architecture, data-quality, or operations documentation.
- [ ] Run all local unit tests and notebook syntax validation.
- [ ] Confirm CI and development preview succeed.
- [ ] Obtain code-owner review before production merge.
- [ ] Run and verify the production pipeline only when a data refresh is needed.

Do not duplicate a second active implementation. Archive superseded examples
under `docs/archive/` and remove them from executable test paths.
