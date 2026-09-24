-- Databricks notebook source
-- ONE-TIME DATABRICKS ADMIN REPAIR
--
-- Purpose:
-- Transfer the existing Analytics and Data Quality views to the identity that
-- currently runs the NYC Mobility production job.
--
-- Run this file once as the CURRENT OWNER of these views or as a Unity Catalog
-- metastore administrator. Do not add this file to the scheduled pipeline.
--
-- Current pipeline run identity observed in the failed run:
--   nicole.salazar@ftwfoundation.org
--
-- If the production job identity changes, replace that principal below before
-- executing this repair.

-- COMMAND ----------

-- Business Analytics views
ALTER VIEW `ftw-week-08`.`03_gold`.`analytics_taxi_demand`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`analytics_weather_behavior`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`analytics_area_mobility_patterns`
OWNER TO `nicole.salazar@ftwfoundation.org`;

-- COMMAND ----------

-- Data Quality Dashboard views
ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_referential_integrity`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_overview`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_check_scores`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_dimension_scores`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_canonical_dimensions`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_problem_areas`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_outside_analysis_window`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_row_reconciliation`
OWNER TO `nicole.salazar@ftwfoundation.org`;

ALTER VIEW `ftw-week-08`.`03_gold`.`dq_dashboard_zone_hotspots`
OWNER TO `nicole.salazar@ftwfoundation.org`;

-- COMMAND ----------

-- Verification: each result should show the production job identity as owner.
DESCRIBE EXTENDED `ftw-week-08`.`03_gold`.`analytics_taxi_demand`;
DESCRIBE EXTENDED `ftw-week-08`.`03_gold`.`dq_dashboard_referential_integrity`;
