-- Databricks notebook source
-- Databricks notebook source
-- Name: Taxi Demand by Day, Hour, and Zone
-- Purpose: Identify when and where Green Taxi demand is highest.
-- Grain: One row per pickup date, day of week, pickup hour, and pickup taxi zone.
-- Depends on: Gold fact_green_taxi_trip, dim_taxi_zone, and dim_time.
-- Why: Supports dashboard rankings of the busiest days, hours, and pickup zones.

SELECT
    TO_DATE(f.pickup_datetime) AS pickup_date,
    DATE_FORMAT(f.pickup_datetime, 'EEEE') AS pickup_day_name,
    f.pickup_time_key AS pickup_hour,
    t.hour_label AS pickup_hour_label,

    z.zone_name AS pickup_zone,
    z.borough AS pickup_borough,

    COUNT(*) AS trip_volume,
    ROUND(AVG(f.trip_duration_minutes), 2) AS avg_trip_duration_minutes,
    ROUND(AVG(f.trip_distance), 2) AS avg_trip_distance_miles,
    ROUND(SUM(f.total_amount), 2) AS total_fare_amount

FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f

LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z
    ON f.pickup_taxi_zone_key = z.taxi_zone_key

LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t
    ON f.pickup_time_key = t.time_key

GROUP BY
    TO_DATE(f.pickup_datetime),
    DATE_FORMAT(f.pickup_datetime, 'EEEE'),
    f.pickup_time_key,
    t.hour_label,
    z.zone_name,
    z.borough

ORDER BY trip_volume DESC;