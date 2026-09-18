# NYC Green Taxi — Mobility & Analytics Dashboard Guide

This document presents the business analytics and technical audit for the **NYC Green Taxi Demand, Weather & Mobility Analytics** dashboard. It details the high-level summary KPIs, visual chart configurations, key business insights, and open governance action items across all four dashboard tabs.

---

##  Executive Summary Cards

The top summary banner provides high-level operational performance metrics across the analyzed dataset.

| KPI Metric | Displayed Value | Metric Description & Audit Note |
| :--- | :---: | :--- |
| **Total Trips** | `133.35K` | Displays ~133,348 valid trips from the analytics layer. *(Note: Raw Gold count is 133,367 prior to filtering 19 out-of-range datetime records).* |
| **Total Fare Revenue** | `3.39M` | Cumulative gross revenue (`total_amount`), including fares, tips, tolls, and surcharges. |
| **Avg Trip Duration (min)** | `21.74` | Average transit time per completed ride across all boroughs. |
| **Avg Trip Distance (mi)** | `3.25` | Average physical distance covered per trip. |
| **Unknown Weather Coverage (%)** | `0` | Percentage of trips missing matched weather observation metrics. |

---

## Spatial Data Governance: `Unknown` vs. `N/A`

Missing geographical attributes manifest as two separate categories in the dataset and are intentionally kept distinct:

* **`Unknown` (Lookup / Geocoding Failure):** The trip contained valid GPS coordinates, but during spatial joining against the NYC Taxi Zone shapefile (`dim_taxi_zone`), the coordinates fell outside defined zone boundaries (e.g., in water bodies, bridges, or unmapped corridors).
* **`N/A` (Missing Source Values / Null Ingestion):** The raw trip record was ingested without location coordinates or IDs entirely (e.g., `pickup_location_id` was `NULL` or `0`). No spatial join was attempted, assigning the default label `'N/A'`.

### Analytics Strategy
Both categories **remain included in the analytics layer** to maintain financial reconciliation (trip counts, miles, and total revenue) without dropping valid transactions.

---

##  Strategic Business Actions & Recommendations

Based on empirical data trends across demand, weather, and zone mobility, the following operational strategies are recommended:

* **Fleet Positioning & Rebalancing:** Since **East Harlem North** shows massive pickup volume (~35K) relative to low drop-off volume (~6K), fleet operations should incentivize drivers to dynamically reposition into East Harlem North after completing drop-offs in adjacent neighborhoods or lower Manhattan.
* **Pricing & Promotional Strategies:** Given that adverse weather (Rain and Snow) severely depresses passenger trip volume, operations should test targeted passenger promotions (e.g., wet-weather ride discounts) alongside surge incentives for drivers during bad weather to retain demand and preserve fleet coverage.
* **Rush-Hour Dispatch Optimization:** Shift scheduling should actively align with peak demand windows (**13:00–18:00**, peaking at **17:00–18:00**) on weekdays, with extended late-night coverage deployed on Friday and Saturday evenings.

---

## Dashboard Tabs & Visual Configurations

### 1. Overview Tab
* **Purpose:** Sets the business context by presenting the core summary KPIs and laying out the three central analytical questions:
  1. *When and where is taxi demand highest?* (Peak hours, days, top pickup zones)
  2. *How does weather affect demand?* (Trip behavior across Clear, Cloudy, Rain, Snow)
  3. *Which zones show mobility opportunities?* (Areas with strong pickup/drop-off activity)

---

### 2. Demand Patterns Tab — "Which Hours and Days See the Most Demand"

* **Which Hours and Days See the Most Demand (Heatmap):**
  * **Visual Type:** 2D Heatmap Grid
  * **Axes:** `pickup_day_name` (Y-Axis) × `pickup_hour_label` (X-Axis, `00:00` to `23:00`)
  * **Color Metric:** `trip_volume`
  * **Key Insight:** Peak demand is heavily concentrated during weekday rush hours and early evenings (**13:00–18:00**, peaking around **17:00–18:00**). Friday and Saturday maintain higher demand into late-night hours.
* **Busiest Pickup Zones by Trip Volume (Horizontal Bar Chart):**
  * **Visual Type:** Horizontal Bar Chart
  * **Axes:** `pickup_zone` (Y-Axis) × `trip_volume` (X-Axis)
  * **Key Insight:** **East Harlem North** (\~35K trips) and **East Harlem South** (\~17K trips) are the top pickup drivers citywide, followed by secondary hubs (*Forest Hills, Morningside Heights, Central Park, Elmhurst, Downtown Brooklyn/MetroTech*).

---

### 3. Weather Impact Tab — "How Weather Affects Taxi Demand and Trip Behavior"

* **How Weather Conditions Affect Trip Demand (Column Chart):**
  * **Visual Type:** Vertical Bar Chart
  * **Axes:** `weather_condition` (X-Axis) × `trip_volume` (Y-Axis)
  * **Key Insight:** **Cloudy** (\~80K) and **Clear** (\~34K) conditions account for the vast majority of trip volume. Demand falls significantly during **Drizzle**, **Rain**, and **Snow**.
* **Average Temperature by Weather Condition (Horizontal Bar Chart):**
  * **Visual Type:** Horizontal Bar Chart
  * **Axes:** `weather_condition` (Y-Axis) × `avg_temperature_c` (X-Axis)
  * **Key Insight:** Tracks operational temperatures per weather type, with **Cloudy** averaging highest (\~14.6°C) and **Snow** dropping to the lowest baseline (\~2.0°C).
* **Trip Volume and Fare by Borough (Data Grid Table):**
  * **Visual Type:** Tabular Summary Matrix
  * **Columns:** `borough`, `trip_volume`, `total_distance_miles`, `avg_fare_per_mile`
  * **Key Insight:** **Manhattan** drives raw volume (77,830 trips / $8.42/mi), followed by **Queens** (30,252 trips / $7.54/mi) and **Brooklyn** (21,418 trips / $7.38/mi). Unmapped spatial corridors (`Unknown`) yield high rates per mile ($28.27/mi) due to long-distance airport transit.

---

### 4. Zone Mobility Tab — "Zone-Level Mobility Patterns and Opportunities"

* **Zones with Strongest Pickup and Dropoff Activity (Grouped Bar Chart):**
  * **Visual Type:** Dual Grouped Horizontal Bar Chart
  * **Axes:** `zone_name` (Y-Axis) × Volume Count (X-Axis)
  * **Series:** `Pickups` (Blue) vs. `Dropoffs` (Orange)
  * **Key Insight:** Uncovers severe directional asymmetry in **East Harlem North** (\~35K pickups vs. \~6K drop-offs) and **East Harlem South** (16.91K pickups vs. 7.85K drop-offs).
* **Pickup Volume Heatmap: Zone × Hour (Heatmap Grid):**
  * **Visual Type:** 2D Heatmap Grid
  * **Axes:** `zone_name` (Y-Axis) × Hour of Day (`00:00` to `23:00`, X-Axis)
  * **Color Metric:** `trip_volume`
  * **Key Insight:** **East Harlem North** sustains dark blue, high-density demand continuously from **07:00 through 18:00**.
* **Key Metric Correlations (Pearson Score Diverging Bar Chart):**
  * **Visual Type:** Diverging Horizontal Bar Chart
  * **Axes:** Metric Relationship (Y-Axis) × `pearson` Score (X-Axis)
  * **Color Scale:** Diverging Gradient (Blue = Positive, Red = Negative)

| Metric Relationship Pair | Pearson $r$ | Statistical & Business Interpretation |
| :--- | :---: | :--- |
| **Average distance vs Average duration** | **+0.63** | Strongest positive relationship — trip distance directly increases duration. |
| **Pickup volume vs Drop-off volume** | **+0.60** | High spatial symmetry — high-volume pickup hubs generally handle high drop-off volume. |
| **Average duration vs Average trip amount** | **+0.23** | Mild positive correlation — longer time in transit increases total fare amount. |
| **Pickup volume vs Adverse-weather share** | **+0.01** | Zero correlation — core pickup volume across major zones is resilient to bad weather. |
| **Drop-off volume vs Average trip amount** | **-0.22** | High-volume drop-off hubs primarily serve shorter, lower-fare trips. |
| **Pickup volume vs Average distance** | **-0.22** | Busiest pickup hubs consist mainly of short, local borough rides. |
| **Pickup volume vs Average duration** | **-0.16** | High pickup volume correlates slightly with shorter transit times. |
| **Pickup volume vs Average trip amount** | **-0.15** | Busiest origin hubs generate lower individual fare amounts. |

---
