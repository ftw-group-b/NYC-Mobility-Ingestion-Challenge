"""Land one approved monthly Open-Meteo JSON response."""

from pathlib import Path
from common import fetch_and_land

import calendar
from datetime import datetime

allowed_months = ["2026-03", "2026-04", "2026-05"]
try:
    weather_month = dbutils.widgets.get("weather_month").strip()
except Exception:
    dbutils.widgets.dropdown("weather_month", "2026-03", allowed_months, "Weather month")
    weather_month = dbutils.widgets.get("weather_month").strip()

if weather_month not in allowed_months:
    raise ValueError(f"weather_month must be one of {allowed_months}")

month_start = datetime.strptime(weather_month, "%Y-%m").date()
month_end_day = calendar.monthrange(month_start.year, month_start.month)[1]
start_date = month_start.isoformat()
end_date = month_start.replace(day=month_end_day).isoformat()

weather_url = (
    f"https://archive-api.open-meteo.com/v1/archive"
    f"?latitude=40.7128"
    f"&longitude=-74.006"
    f"&start_date={start_date}"
    f"&end_date={end_date}"
    f"&hourly=temperature_2m,precipitation,rain,snowfall,weather_code,wind_speed_10m"
    f"&timezone=America%2FNew_York"
)

weather_filename = f"open_meteo_{start_date}_{end_date}.json"
weather_path = (
    Path("/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/")
    / "groups/week-08/group-b/source/weather"
    / weather_filename
)

print("Selected month:", weather_month)
print("Date range:", start_date, "to", end_date)
weather_evidence = fetch_and_land(
    weather_url,
    weather_path,
    source_system="open_meteo",
)
