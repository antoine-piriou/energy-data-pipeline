"""Open-Meteo historical weather for Paris (archive API, no key needed).

One point only: Paris temperature is used as a proxy for French temperature,
which drives electricity demand through electric heating.
One call returns one UTC day of hourly values as raw JSON, stored as is.
"""

from datetime import date

import requests

from energy_pipeline import http

BASE_URL = "https://archive-api.open-meteo.com/v1/archive"
LATITUDE = 48.8566  # Paris
LONGITUDE = 2.3522
HOURLY_VARIABLES = "temperature_2m"  # comma separated if several
EXTENSION = "json"


def fetch(day: date, *, session: requests.Session | None = None) -> bytes:
    """Return the raw JSON response for `day`: one value per hour, 00:00 to 23:00 UTC."""
    # Dates as YYYY-MM-DD; Open-Meteo includes end_date in the result
    start = day.isoformat()
    end = day.isoformat()  # same day: one day only

    params = {
        "latitude": LATITUDE,
        "longitude": LONGITUDE,
        "start_date": start,
        "end_date": end,
        "hourly": HOURLY_VARIABLES,
        "timezone": "UTC",
    }

    return http.get(BASE_URL, params, session=session)
