"""RTE eCO2mix national data, from the ODRE open data portal (Opendatasoft API v2.1).

Dataset: eco2mix-national-cons-def (consolidated and definitive data, for backfill).
One call returns one UTC day as raw CSV (";" separated), stored as is.
"""

from datetime import date, timedelta

import requests

from energy_pipeline import http

BASE_URL = "https://odre.opendatasoft.com/api/explore/v2.1/catalog/datasets"
DATASET = "eco2mix-national-cons-def"
EXTENSION = "csv"


def fetch(day: date, *, session: requests.Session | None = None) -> bytes:
    """Return the raw CSV export of `day` (00:00 to 24:00 UTC)."""
    # Export endpoint: the whole day in one call (/records stops at 100 rows)
    url = f"{BASE_URL}/{DATASET}/exports/csv"

    # UTC bounds of the day; the end is the start of the next day, excluded
    start = f"{day.isoformat()}T00:00:00Z"
    end = f"{(day + timedelta(days=1)).isoformat()}T00:00:00Z"

    # Filter on date_heure (UTC); date/heure columns are Paris local time
    params = {
        "where": f"date_heure >= '{start}' and date_heure < '{end}'",
        "order_by": "date_heure",
        "timezone": "UTC",
    }

    return http.get(url, params, session=session)
