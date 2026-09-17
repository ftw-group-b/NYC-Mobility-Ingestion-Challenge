-- Databricks notebook source
-- 1. Referential Integrity
CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.dq_dashboard_referential_integrity AS
SELECT
  SUM(CASE WHEN d_pickup.date_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_date_keys,
  SUM(CASE WHEN d_dropoff.date_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_date_keys,
  SUM(CASE WHEN t_pickup.time_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_time_keys,
  SUM(CASE WHEN t_dropoff.time_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_time_keys,
  SUM(CASE WHEN z_pickup.taxi_zone_key IS NULL THEN 1 ELSE 0 END) AS missing_pickup_zone_keys,
  SUM(CASE WHEN z_dropoff.taxi_zone_key IS NULL THEN 1 ELSE 0 END) AS missing_dropoff_zone_keys,
  SUM(CASE WHEN w.weather_hour_key IS NULL THEN 1 ELSE 0 END) AS missing_weather_keys,
  COUNT(*) AS joined_rows,
  (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip) AS fact_rows,
  COUNT(*) - (SELECT COUNT(*) FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip) AS join_row_difference
FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_pickup ON f.pickup_date_key = d_pickup.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_date AS d_dropoff ON f.dropoff_date_key = d_dropoff.date_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_pickup ON f.pickup_time_key = t_pickup.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t_dropoff ON f.dropoff_time_key = t_dropoff.time_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_pickup ON f.pickup_taxi_zone_key = z_pickup.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z_dropoff ON f.dropoff_taxi_zone_key = z_dropoff.taxi_zone_key
LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w ON f.pickup_weather_hour_key = w.weather_hour_key;
