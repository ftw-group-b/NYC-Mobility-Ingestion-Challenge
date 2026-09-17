"""Land one approved monthly NYC Green Taxi Parquet file."""

from pathlib import Path
from common import fetch_and_land

allowed_taxi_months = ["2026-03", "2026-04", "2026-05"]
try:
    green_taxi_month = dbutils.widgets.get("green_taxi_month").strip()
except Exception:
    dbutils.widgets.dropdown(
        "green_taxi_month",
        "2026-03",
        allowed_taxi_months,
        "Green Taxi month",
    )
    green_taxi_month = dbutils.widgets.get("green_taxi_month").strip()

if green_taxi_month not in allowed_taxi_months:
    raise ValueError(f"green_taxi_month must be one of {allowed_taxi_months}")

green_taxi_filename = f"green_tripdata_{green_taxi_month}.parquet"
green_taxi_url = (
    "https://d37ci6vzurychx.cloudfront.net/trip-data/"
    f"{green_taxi_filename}"
)
green_taxi_path = (
    Path("/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/")
    / "groups/week-08/group-b/source/green_taxi"
    / green_taxi_filename
)

green_taxi_evidence = fetch_and_land(
    green_taxi_url,
    green_taxi_path,
    source_system="nyc_tlc",
)
