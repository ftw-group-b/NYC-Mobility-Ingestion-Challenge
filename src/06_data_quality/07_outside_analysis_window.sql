-- Databricks notebook source
-- 7. Outside Analysis Window
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_outside_analysis_window AS
SELECT
  trip_key,
  pickup_datetime,
  dropoff_datetime,
  source_file,
  batch_id
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
WHERE dq_out_of_range_datetime = TRUE;
