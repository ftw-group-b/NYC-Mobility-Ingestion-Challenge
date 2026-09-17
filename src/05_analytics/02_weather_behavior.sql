-- Databricks notebook source
-- Name: Weather and Green Taxi Trip Behavior
-- Purpose: Compare taxi demand, trip duration, distance, and fares across weather.
-- Grain: One row per weather condition and weather code.
-- Depends on: Gold fact_green_taxi_trip and dim_weather_hour.
-- Why: Shows observed relationships between hourly weather conditions and taxi trips.
-- Note: This is an association analysis, not evidence that weather caused changes.
-- Note: weather_code = NULL corresponds to the dim_weather_hour "Unknown" member
--       (weather_hour_key = 0) for trips with no matched weather observation;
--       these fall into 'Other / Unknown' below rather than being dropped.
-- Note: Weather measures below are trip-weighted, not hour-weighted — one hourly
--       weather reading repeats once per trip in that hour, so busier hours carry
--       proportionally more weight in the averages.

CREATE OR REPLACE VIEW `ftw-week-08`.`03_gold`.analytics_weather_behavior AS
WITH trip_weather AS (
    SELECT
        f.trip_key,
        f.trip_duration_minutes,
        f.trip_distance,
        f.fare_amount,
        f.total_amount,

        w.weather_code,
        w.temperature_2m,
        w.precipitation,
        w.rain,
        w.snowfall,
        w.wind_speed_10m,

        -- Exact WMO weather-code classification (matches area_mobility_patterns.sql):
        CASE
            WHEN w.weather_code = 0 THEN 'Clear'
            WHEN w.weather_code IN (1, 2, 3) THEN 'Cloudy'
            WHEN w.weather_code IN (45, 48) THEN 'Fog'
            WHEN w.weather_code IN (51, 53, 55, 56, 57) THEN 'Drizzle'
            WHEN w.weather_code IN (61, 63, 65, 66, 67, 80, 81, 82) THEN 'Rain'
            WHEN w.weather_code IN (71, 73, 75, 77, 85, 86) THEN 'Snow'
            WHEN w.weather_code IN (95, 96, 99) THEN 'Thunderstorm'
            ELSE 'Other / Unknown'
        END AS weather_condition

    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f

    INNER JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w
        ON f.pickup_weather_hour_key = w.weather_hour_key

    WHERE f.dq_out_of_range_datetime = FALSE
)

SELECT
    weather_condition,
    weather_code,

    COUNT(*) AS trip_volume,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_trip_duration_minutes,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance_miles,
    ROUND(AVG(fare_amount), 2) AS avg_fare_amount,
    ROUND(SUM(total_amount), 2) AS total_trip_amount,

    ROUND(AVG(temperature_2m), 2) AS trip_weighted_avg_temperature_c,
    ROUND(AVG(precipitation), 2) AS trip_weighted_avg_precipitation_mm,
    ROUND(AVG(rain), 2) AS trip_weighted_avg_rain_mm,
    ROUND(AVG(snowfall), 2) AS trip_weighted_avg_snowfall_cm,
    ROUND(AVG(wind_speed_10m), 2) AS trip_weighted_avg_wind_speed_10m

FROM trip_weather

GROUP BY
    weather_condition,
    weather_code

ORDER BY trip_volume DESC;
