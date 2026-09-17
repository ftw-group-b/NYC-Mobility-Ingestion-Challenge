"""Land the NYC TLC Taxi Zone lookup."""

from pathlib import Path
from common import fetch_and_land

taxi_zone_url = (
    "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"
)
taxi_zone_path = (
    Path("/Volumes/ftw-week-08/00_source_inspection/cloudfare-r2/")
    / "groups/week-08/group-b/source/taxi_zones"
    / "taxi_zone_lookup.csv"
)

taxi_zone_evidence = fetch_and_land(
    taxi_zone_url,
    taxi_zone_path,
    source_system="nyc_tlc",
)
