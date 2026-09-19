-- Databricks notebook source
-- Modular source: Gold Green Taxi fact

CREATE OR REPLACE TABLE `ftw-week-08`.`03_gold`.fact_green_taxi_trip
USING DELTA
AS
SELECT
    xxhash64(
        g.VendorID,
        g.lpep_pickup_datetime,
        g.lpep_dropoff_datetime,
        g.store_and_fwd_flag,
        g.RatecodeID,
        g.PULocationID,
        g.DOLocationID,
        g.passenger_count,
        g.trip_distance,
        g.trip_duration_minutes,
        g.fare_amount,
        g.extra,
        g.mta_tax,
        g.tip_amount,
        g.tolls_amount,
        g.improvement_surcharge,
        g.total_amount,
        g.payment_type,
        g.trip_type,
        g.congestion_surcharge,
        g.cbd_congestion_fee,
        g.source_file
    ) AS trip_key,

    g.VendorID AS vendor_id,
    g.lpep_pickup_datetime AS pickup_datetime,
    g.lpep_dropoff_datetime AS dropoff_datetime,

    CAST(DATE_FORMAT(TO_DATE(g.lpep_pickup_datetime), 'yyyyMMdd') AS INT)
        AS pickup_date_key,
    CAST(DATE_FORMAT(TO_DATE(g.lpep_dropoff_datetime), 'yyyyMMdd') AS INT)
        AS dropoff_date_key,

    COALESCE(HOUR(g.lpep_pickup_datetime) + 1, 0) AS pickup_time_key,
    COALESCE(HOUR(g.lpep_dropoff_datetime) + 1, 0) AS dropoff_time_key,

    CAST(g.PULocationID AS INT) AS pickup_taxi_zone_key,
    CAST(g.DOLocationID AS INT) AS dropoff_taxi_zone_key,
    COALESCE(w.weather_hour_key, CAST(0 AS BIGINT)) AS pickup_weather_hour_key,

    CAST(1 AS BIGINT) AS trip_count,
    g.passenger_count,
    g.trip_distance,
    g.trip_duration_minutes,
    CASE
        WHEN g.trip_duration_minutes > 0
        THEN g.trip_distance / (g.trip_duration_minutes / 60.0)
    END AS trip_average_speed_mph,
    CASE
        WHEN g.trip_distance > 0
        THEN g.total_amount / g.trip_distance
    END AS total_amount_per_mile,

    g.fare_amount,
    g.extra,
    g.mta_tax,
    g.tip_amount,
    g.tolls_amount,
    g.improvement_surcharge,
    g.congestion_surcharge,
    g.cbd_congestion_fee,
    g.total_amount,

    g.payment_type,
    g.payment_type_description,
    g.trip_type,
    g.RatecodeID AS rate_code_id,
    g.store_and_fwd_flag,

    g.dq_zero_trip_distance,
    g.dq_extreme_trip_distance,
    g.dq_negative_trip_distance,
    g.dq_out_of_range_datetime,
    g.dq_invalid_trip_duration,
    w.weather_hour_key IS NULL AS dq_missing_weather_coverage,

    g.source_system,
    g.source_file,
    g.batch_id

FROM `ftw-week-08`.`02_silver`.green_taxi AS g
LEFT JOIN `ftw-week-08`.`03_gold`.dim_weather_hour AS w
    ON w.weather_hour_key = CAST(
        DATE_FORMAT(g.pickup_hour, 'yyyyMMddHH') AS BIGINT
    )
   AND w.weather_hour_key != 0;
