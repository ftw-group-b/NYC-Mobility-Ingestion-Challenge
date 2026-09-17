-- Databricks notebook source
-- 8. Row Reconciliation
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_row_reconciliation AS
WITH silver_summary AS (
  SELECT COUNT(*) AS silver_row_count
  FROM `ftw-week-08`.`02_silver`.green_taxi
),
gold_summary AS (
  SELECT COUNT(*) AS gold_row_count
  FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
)
SELECT
  s.silver_row_count,
  g.gold_row_count,
  g.gold_row_count - s.silver_row_count AS row_count_difference,
  ROUND(100.0 * g.gold_row_count / NULLIF(s.silver_row_count, 0), 3) AS gold_retention_pct
FROM silver_summary AS s
CROSS JOIN gold_summary AS g;
