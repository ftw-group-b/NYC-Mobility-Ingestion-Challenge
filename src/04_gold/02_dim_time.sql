-- Databricks notebook source
-- Modular source: Gold Time dimension

CREATE OR REPLACE TABLE `ftw-week-08`.`03_gold`.dim_time
USING DELTA
AS
SELECT
    0 AS time_key,
    CAST(NULL AS INT) AS hour_24,
    'Unknown' AS hour_label,
    'Unknown' AS day_period

UNION ALL

SELECT
    hour_24 + 1 AS time_key,
    hour_24,
    CONCAT(
        LPAD(CAST(hour_24 AS STRING), 2, '0'),
        ':00'
    ) AS hour_label,
    CASE
        WHEN hour_24 < 12 THEN 'AM'
        ELSE 'PM'
    END AS day_period
FROM (
    SELECT EXPLODE(SEQUENCE(0, 23)) AS hour_24
);
