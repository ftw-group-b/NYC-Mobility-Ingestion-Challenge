# Reusability Review — NYC Mobility Pipeline

**Reviewer:** Joy Balansay  
**Review date:** 24 September 2026  
**Reviewed baseline:** [`206371b`](https://github.com/ftw-group-b/NYC-Mobility-Ingestion-Challenge/commit/206371bd798c5f7965a2dbccf55383d0c01a1cc8) on `main`  
**Status:** Review completed; Phase 2 implementation proposed.

## Summary

The pipeline has a reusable foundation: a shared ingestion helper, a selectable Green Taxi month, and separate bundle deployment targets. Reusing the complete pipeline in another environment or for another approved period still requires coordinated configuration changes.

The assessment is **moderate reusability**, consistent with the team's improvement guide. That guide places environment isolation and further parameterization in Phase 2 and states that they are not required to finish the current assignment.

This document records the code and documentation review. It does not establish that Phase 2 has been implemented or runtime-tested. No Databricks pipeline run was performed as part of this review.

## Findings and basis

| Area | Verified observation | Effect on reuse | Suggested improvement |
| --- | --- | --- | --- |
| Shared ingestion helper | [`common.py`](https://github.com/ftw-group-b/NYC-Mobility-Ingestion-Challenge/blob/206371bd798c5f7965a2dbccf55383d0c01a1cc8/src/01_ingestion/common.py) defines `fetch_and_land`, taking the source URL, target path, source system, and retry settings as inputs. | Downloading and landing logic can be reused across sources. | Continue using this helper when configuring source-specific inputs. Preserve its metadata checks and rerun behavior. |
| Green Taxi period and path | [`01_green_taxi.py`](https://github.com/ftw-group-b/NYC-Mobility-Ingestion-Challenge/blob/206371bd798c5f7965a2dbccf55383d0c01a1cc8/src/01_ingestion/01_green_taxi.py#L6-L29) reads a month widget and builds the filename dynamically. The allowed months are March–May 2026, and the Volume path is fixed. | Month selection is already parameterized within the approved baseline. A different period or landing location requires edits. | Centralize the approved months and landing root while keeping month validation. |
| Environment isolation | [`databricks.yml`](https://github.com/ftw-group-b/NYC-Mobility-Ingestion-Challenge/blob/206371bd798c5f7965a2dbccf55383d0c01a1cc8/databricks.yml) separates dev/prod workspace roots. [`CONFIGURATION.md`](https://github.com/ftw-group-b/NYC-Mobility-Ingestion-Challenge/blob/206371bd798c5f7965a2dbccf55383d0c01a1cc8/docs/operations/CONFIGURATION.md#L19-L34) explicitly documents that notebooks still use `ftw-week-08` and fixed schemas/Volume paths. | Separate deployment folders do not yet provide separate data destinations. | Configure a separate development catalog and Volume, then pass catalog, schema, and landing settings through the pipeline. |
| Weather source selection | [Silver weather SQL](https://github.com/ftw-group-b/NYC-Mobility-Ingestion-Challenge/blob/206371bd798c5f7965a2dbccf55383d0c01a1cc8/src/03_silver/03_weather.sql#L42-L44) selects the fixed `open_meteo_2026-03-01_2026-05-31.json` source file and batch ID. | Changing only the ingestion period would leave downstream selection tied to the existing batch. | Update ingestion and downstream weather source selection together when extending the approved period. |
| Validation inputs and outputs | The [GX quality-gate notebook](https://github.com/ftw-group-b/NYC-Mobility-Ingestion-Challenge/blob/206371bd798c5f7965a2dbccf55383d0c01a1cc8/tests/end_to_end/02_great_expectations_quality_gate.ipynb) reads fixed `ftw-week-08` tables and sets `catalog = "ftw-week-08"` and `schema = "03_gold"` for result destinations. | Environment configuration must also cover validation and published results. | Pass the selected environment settings to validation inputs and result destinations. |

## Proposed Phase 2 sequence

1. **Define the environment settings.** Confirm the development catalog, schema names, and complete landing Volume path with the team. Use the existing production settings as the baseline.
2. **Connect configuration to execution.** Add environment settings to the bundle and pass them as job parameters for notebooks to consume.
3. **Migrate one layer at a time.** Follow the team's order: Ingestion → Bronze → Silver → Gold → Analytics → GX. Include validation notebooks and dashboard/data-quality views that read or write the affected objects. Keep modular source files and executable notebooks aligned.
4. **Address period settings after environment settings.** Centralize approved months and coordinate weather filenames, batch selection, and downstream date assumptions.
5. **Record validation evidence in the implementation PR.** Capture the selected configuration, relevant run links, reconciliation results, and remaining limitations.

The existing [configuration guidance](CONFIGURATION.md) requires a separate development catalog and Volume before running a development job that writes data. Validate all affected destinations before each controlled run; migrate the references deliberately rather than applying a repository-wide replacement.

## Completion criteria for future implementation

- [ ] Development reads and writes resolve to the intended development resources, including GX results and data-quality views.
- [ ] Production configuration resolves to the existing approved production resources.
- [ ] The approved baseline still passes layer validations, row-count/measure reconciliation, and the final GX gate.
- [ ] Repeating the same approved input preserves the existing rerun safeguards and does not introduce duplicate loads.
- [ ] Any newly approved period is selected consistently from ingestion through weather processing, analytics, and validation.
- [ ] Configuration instructions, source files, notebooks, and tests are aligned and reviewed.

These boxes describe future implementation acceptance criteria; they are not results from this review.

## Review outcome

The reusability review is complete. The findings identify what is already reusable, where settings remain fixed, and the coordinated changes needed for Phase 2. The next implementation can use this document as its scope and evidence checklist.

### Related documentation

- [Environment and deployment configuration](CONFIGURATION.md)
- [Change checklist](CHANGE_CHECKLIST.md)
- [Operations runbook](RUNBOOK.md)
