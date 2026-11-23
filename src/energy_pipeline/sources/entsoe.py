"""ENTSO-E Transparency Platform: actual total load of Germany (REST API, token needed).

Dataset: documentType A65 (system total load), processType A16 (realised).
One call returns one UTC day as raw XML, stored as is.

Security: the token goes in the query string, so it must never be logged.
http.get only logs the base URL, and setup_logging keeps urllib3 quiet.
"""

from datetime import date, timedelta

import requests

from energy_pipeline import config, http

BASE_URL = "https://web-api.tp.entsoe.eu/api"
GERMANY = "10Y1001A1001A83F"  # EIC code of the Germany control area
EXTENSION = "xml"


def period(day: date) -> tuple[str, str]:
    """Return the UTC bounds of `day` in ENTSO-E format (yyyyMMddHHmm), end excluded."""
    start = day.strftime("%Y%m%d0000")
    end = (day + timedelta(days=1)).strftime("%Y%m%d0000")
    return start, end


def fetch(day: date, *, session: requests.Session | None = None) -> bytes:
    """Return the raw XML load document of `day` (00:00 to 24:00 UTC)."""
    # Read at call time: other sources must work without a token
    token = config.get_entsoe_token()
    start, end = period(day)

    params = {
        "securityToken": token,
        "documentType": "A65",
        "processType": "A16",
        "outBiddingZone_Domain": GERMANY,
        "periodStart": start,
        "periodEnd": end,
    }

    return http.get(BASE_URL, params, session=session)
