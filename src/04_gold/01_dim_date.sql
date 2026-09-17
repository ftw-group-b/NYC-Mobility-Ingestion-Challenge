-- Databricks notebook source
-- Modular source: Gold Date dimension

CREATE OR REPLACE TABLE `ftw-week-08`.`03_gold`.dim_date
USING DELTA
AS
WITH required_dates AS (

    SELECT TO_DATE(lpep_pickup_datetime) AS full_date
    FROM `ftw-week-08`.`02_silver`.green_taxi

    UNION

    SELECT TO_DATE(lpep_dropoff_datetime) AS full_date
    FROM `ftw-week-08`.`02_silver`.green_taxi

),

date_range AS (
    SELECT
        MIN(full_date) AS min_date,
        MAX(full_date) AS max_date
    FROM required_dates
    WHERE full_date IS NOT NULL
),

dates AS (
    SELECT EXPLODE(
        SEQUENCE(min_date, max_date, INTERVAL 1 DAY)
    ) AS full_date
    FROM date_range
)

SELECT
    CAST(DATE_FORMAT(full_date, 'yyyyMMdd') AS INT) AS date_key,
    full_date,
    YEAR(full_date) AS year,
    QUARTER(full_date) AS quarter,
    MONTH(full_date) AS month_number,
    DATE_FORMAT(full_date, 'MMMM') AS month_name,
    DAYOFMONTH(full_date) AS day_of_month,
    DATE_FORMAT(full_date, 'EEEE') AS day_name,
    DAYOFWEEK(full_date) AS day_of_week,
    DAYOFWEEK(full_date) IN (1, 7) AS is_weekend,
    CAST(NULL AS BOOLEAN) AS is_holiday
FROM dates;
