# Business-Ready Analytics Dashboard

## Overview and key performance indicators

![Business Analytics overview and KPIs](../../docs/assets/business_analytics_dashboard/01_overview_and_kpis.svg)

## Taxi demand

![Taxi demand dashboard](../../docs/assets/business_analytics_dashboard/02_taxi_demand.svg)

## Weather and trip behavior

![Weather behavior dashboard](../../docs/assets/business_analytics_dashboard/03_weather_behavior.svg)

## Zone-level mobility patterns

![Mobility patterns dashboard](../../docs/assets/business_analytics_dashboard/04_mobility_patterns.svg)

The dashboard reads three Gold views created under `notebooks/05_analytics/`:

- `analytics_taxi_demand`
- `analytics_weather_behavior`
- `analytics_area_mobility_patterns`

Recommended pages:

1. Demand by date, weekday, hour, and pickup zone
2. Weather-associated demand and trip behavior
3. Pickup/drop-off area patterns and peak pickup hours

All queries filter `dq_out_of_range_datetime = FALSE` for the March-May assignment window. Weather results describe association, not causation.

The separate checks in `tests/analytics/` reconcile dashboard trip volumes and verify each view's declared grain.
