-- Databricks notebook source
-- Name: Area Mobility Patterns
-- Purpose: Compare pickup/drop-off activity, trip characteristics, trip amounts, peak pickup hours, and weather-related pickup patterns across NYC taxi zones.
-- Grain: One row per pickup taxi zone.
-- All metrics are aggregated to the pickup taxi zone level
-- Depends on: Gold fact_green_taxi_trip, dim_taxi_zone, and dim_weather_hour.
-- Why: Supports comparison of mobility patterns across NYC taxi zones.
-- Note: High activity or trip amounts do not automatically indicate profitability, revenue, or underserved areas.

WITH pickup_metrics AS (
    SELECT
        f.pickup_taxi_zone_key AS taxi_zone_key,

-- Number of distinct calendar dates with at least one pickup
        COUNT(*) AS pickup_trip_volume,
        COUNT(DISTINCT TO_DATE(f.pickup_datetime)) AS active_pickup_days,

        ROUND(AVG(f.trip_duration_minutes), 2) AS avg_trip_duration_minutes,
        ROUND(AVG(f.trip_distance), 2) AS avg_trip_distance_miles,
        ROUND(SUM(f.total_amount), 2) AS total_trip_amount,
        ROUND(AVG(f.total_amount), 2) AS avg_trip_amount,

-- Count of pickups whose weather hour falls under an adverse WMO weather code,
-- per the classification defined by WMO weather-code mapping

        SUM(
            CASE
                WHEN w.weather_code BETWEEN 51 AND 67
                  OR w.weather_code BETWEEN 71 AND 77
                  OR w.weather_code BETWEEN 80 AND 86
                  OR w.weather_code BETWEEN 95 AND 99
                THEN 1
                ELSE 0
            END
        ) AS adverse_weather_pickups,

-- Count pickups occurring under clear/cloudy weather codes.
-- WMO weather-code ranges classified as adverse conditions:
--   51-57 = Drizzle
--   61-67 = Rain
--   71-77 = Snow
--   80-86 = Showers
--   95-99 = Thunderstorm

        SUM(
            CASE
                WHEN w.weather_code IN (0, 1, 2, 3)
                THEN 1
                ELSE 0
            END
        ) AS clear_or_cloudy_pickups

    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f

    LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w
        ON f.pickup_weather_hour_key = w.weather_hour_key

    WHERE dq_out_of_range_datetime = FALSE
    GROUP BY f.pickup_taxi_zone_key
),

dropoff_metrics AS (
    SELECT
        dropoff_taxi_zone_key AS taxi_zone_key,
        COUNT(*) AS dropoff_trip_volume

    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
    WHERE dq_out_of_range_datetime = FALSE
    GROUP BY dropoff_taxi_zone_key
),

zone_hour_counts AS (
    SELECT
        pickup_taxi_zone_key AS taxi_zone_key,
        pickup_time_key AS pickup_hour,
        COUNT(*) AS trip_volume

    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip
    WHERE dq_out_of_range_datetime = FALSE
    GROUP BY
        pickup_taxi_zone_key,
        pickup_time_key
),

peak_hour AS (
    SELECT
        taxi_zone_key,
        pickup_hour AS peak_pickup_hour,
        trip_volume AS peak_hour_trip_volume

    FROM (
        SELECT
            taxi_zone_key,
            pickup_hour,
            trip_volume,
            ROW_NUMBER() OVER (
                PARTITION BY taxi_zone_key
                ORDER BY trip_volume DESC, pickup_hour
            ) AS hour_rank
        FROM zone_hour_counts
    )
    WHERE hour_rank = 1
)

SELECT
    z.zone_name,
    z.borough,
    z.service_zone,

    p.pickup_trip_volume,
    COALESCE(d.dropoff_trip_volume, 0) AS dropoff_trip_volume,
    p.active_pickup_days,

    p.avg_trip_duration_minutes,
    p.avg_trip_distance_miles,
    p.total_trip_amount,
    p.avg_trip_amount,

    ph.peak_pickup_hour,
    ph.peak_hour_trip_volume,

    p.adverse_weather_pickups,
    p.clear_or_cloudy_pickups,

-- Percentage of classified pickups (adverse + clear/cloudy) that occurred in adverse weather.
-- Trips with an unclassified weather condition (e.g. Fog, Unknown) are excluded from the denominator.

    ROUND(
        100.0 * p.adverse_weather_pickups /
        NULLIF(
            p.adverse_weather_pickups + p.clear_or_cloudy_pickups,
            0
        ),
        2
    ) AS adverse_weather_pickup_share_pct

FROM pickup_metrics AS p

LEFT JOIN dropoff_metrics AS d
    ON p.taxi_zone_key = d.taxi_zone_key

LEFT JOIN peak_hour AS ph
    ON p.taxi_zone_key = ph.taxi_zone_key

LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z
    ON p.taxi_zone_key = z.taxi_zone_key

ORDER BY
    p.pickup_trip_volume DESC,
    p.total_trip_amount DESC;