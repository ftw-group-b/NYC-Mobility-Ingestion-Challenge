-- Databricks notebook source
-- Databricks notebook source
-- Name: Area Mobility Patterns
-- Purpose: Compare pickup/drop-off activity, trip characteristics, trip amounts, peak pickup hours, and weather-related pickup patterns across NYC taxi zones.
-- Grain: One row per pickup taxi zone; all metrics are aggregated to this level.
-- Depends on: Gold fact_green_taxi_trip, dim_taxi_zone, dim_time, and dim_weather_hour.
-- Why: Supports comparison of mobility patterns across NYC taxi zones.
-- Note: High activity or trip amounts do not automatically indicate profitability, revenue, or underserved areas.
--       (avg_trip_duration_minutes, avg_trip_distance_miles, total_trip_amount, avg_trip_amount,
--       adverse_weather_pickups, clear_or_cloudy_pickups, adverse_weather_pickup_share_pct, and
--       peak_pickup_hour_*) are NULL rather than 0 — there's no pickup trip to compute them from.

WITH pickup_metrics AS (
    SELECT
        f.pickup_taxi_zone_key AS taxi_zone_key,

        COUNT(*) AS pickup_trip_volume, -- Number of accepted Green Taxi trip records originating from the zone
        COUNT(DISTINCT TO_DATE(f.pickup_datetime)) AS active_pickup_days, -- Number of distinct calendar dates with at least one pickup

        ROUND(AVG(f.trip_duration_minutes), 2) AS avg_trip_duration_minutes,
        ROUND(AVG(f.trip_distance), 2) AS avg_trip_distance_miles,
        ROUND(SUM(f.total_amount), 2) AS total_trip_amount,
        ROUND(AVG(f.total_amount), 2) AS avg_trip_amount,

        -- Count of pickups whose weather hour falls under an adverse WMO weather code
        -- (exact codes, matching weather_behavior.sql's classification):
        --   51, 53, 55, 56, 57 = Drizzle
        --   61, 63, 65, 66, 67, 80, 81, 82 = Rain
        --   71, 73, 75, 77, 85, 86 = Snow
        --   95, 96, 99 = Thunderstorm
        SUM(
            CASE
                WHEN w.weather_code IN (
                    51, 53, 55, 56, 57,
                    61, 63, 65, 66, 67,
                    71, 73, 75, 77,
                    80, 81, 82,
                    85, 86,
                    95, 96, 99
                )
                THEN 1
                ELSE 0
            END
        ) AS adverse_weather_pickups,

        -- Count pickups occurring under clear/cloudy weather codes (WMO 0-3).
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

    WHERE f.dq_out_of_range_datetime = FALSE
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
        f.pickup_taxi_zone_key AS taxi_zone_key,
        t.hour_24 AS pickup_hour_24,
        t.hour_label AS pickup_hour_label,
        COUNT(*) AS trip_volume

    FROM `ftw-week-08`.`03_gold`.fact_green_taxi_trip AS f

    LEFT JOIN `ftw-week-08`.`03_gold`.dim_time AS t
        ON f.pickup_time_key = t.time_key

    WHERE f.dq_out_of_range_datetime = FALSE

    GROUP BY
        f.pickup_taxi_zone_key,
        t.hour_24,
        t.hour_label
),

peak_hour AS (
    SELECT
        taxi_zone_key,
        pickup_hour_24 AS peak_pickup_hour_24,
        pickup_hour_label AS peak_pickup_hour_label,
        trip_volume AS peak_hour_trip_volume

    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY taxi_zone_key
                ORDER BY
                    trip_volume DESC,
                    pickup_hour_24 ASC NULLS LAST
            ) AS hour_rank
        FROM zone_hour_counts
    )
    WHERE hour_rank = 1
)

SELECT
    z.zone_name,
    z.borough,
    z.service_zone,

    COALESCE(p.pickup_trip_volume, 0) AS pickup_trip_volume,
    COALESCE(d.dropoff_trip_volume, 0) AS dropoff_trip_volume,
    COALESCE(p.active_pickup_days, 0) AS active_pickup_days,

    p.avg_trip_duration_minutes,
    p.avg_trip_distance_miles,
    p.total_trip_amount,
    p.avg_trip_amount,

    ph.peak_pickup_hour_24,
    ph.peak_pickup_hour_label,
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

FULL OUTER JOIN dropoff_metrics AS d
    ON p.taxi_zone_key = d.taxi_zone_key

LEFT JOIN peak_hour AS ph
    ON p.taxi_zone_key = ph.taxi_zone_key

LEFT JOIN `ftw-week-08`.`03_gold`.dim_taxi_zone AS z
    ON COALESCE(p.taxi_zone_key, d.taxi_zone_key) = z.taxi_zone_key

ORDER BY
    COALESCE(p.pickup_trip_volume, 0) DESC,
    COALESCE(p.total_trip_amount, 0) DESC;