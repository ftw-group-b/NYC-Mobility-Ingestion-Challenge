-- Databricks notebook source
-- 5. Canonical Dimensions Catalog
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_canonical_dimensions AS
WITH dimension_catalog AS (
  SELECT dimension_order, dimension_key, dimension_label
  FROM VALUES
    (1, 'COMPLETENESS', 'Completeness'),
    (2, 'VALIDITY', 'Validity'),
    (3, 'UNIQUENESS', 'Uniqueness'),
    (4, 'CONSISTENCY', 'Consistency'),
    (5, 'ACCURACY', 'Accuracy'),
    (6, 'AUDITABILITY', 'Auditability'),
    (7, 'TIMELINESS_VOLUME', 'Timeliness / Volume')
    AS catalog(dimension_order, dimension_key, dimension_label)
)
SELECT
  catalog.dimension_order,
  catalog.dimension_key,
  catalog.dimension_label,
  scores.flagged_rows,
  COALESCE(
    scores.total_rows,
    (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip)
  ) AS total_rows,
  scores.flagged_pct,
  COALESCE(scores.checks_in_dimension, 0) AS checks_in_dimension,
  CASE
    WHEN scores.quality_dimension IS NOT NULL
      THEN 'MEASURED'
    WHEN catalog.dimension_key IN ('CONSISTENCY', 'TIMELINESS_VOLUME')
      THEN 'MEASURED_SEPARATELY'
    ELSE 'NOT_MEASURED'
  END AS measurement_status,
  CASE
    WHEN catalog.dimension_key = 'ACCURACY'
      THEN 'N/A - no external ground truth for reconciliation'
    WHEN catalog.dimension_key = 'CONSISTENCY'
      THEN 'See dq_dashboard_referential_integrity for FK checks'
    WHEN catalog.dimension_key = 'TIMELINESS_VOLUME'
      THEN 'See dq_dashboard_row_reconciliation for Silver-to-Gold row counts'
    WHEN catalog.dimension_key = 'AUDITABILITY'
      THEN 'Measured from required source_system, source_file, and batch_id lineage'
    ELSE 'Directly measured from fact_green_taxi_trip dq_* flags'
  END AS measurement_note
FROM dimension_catalog AS catalog
LEFT JOIN `ftw-week-08`.`03_gold`.dq_dashboard_dimension_scores AS scores
  ON catalog.dimension_key = scores.quality_dimension;
