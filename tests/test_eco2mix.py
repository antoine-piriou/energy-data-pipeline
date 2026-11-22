from datetime import date
from pathlib import Path

from energy_pipeline.sources import eco2mix

FIXTURE = Path(__file__).parent / "fixtures" / "eco2mix_sample.csv"


class FakeResponse:
    def __init__(self, status_code, content=b""):
        self.status_code = status_code
        self.content = content


class FakeSession:
    """Always answer with `content`, and remember the params of the last call."""

    def __init__(self, content):
        self.content = content
        self.params = None

    def get(self, url, params=None, timeout=None):
        self.params = params
        return FakeResponse(200, self.content)


def test_fetch_returns_raw_csv_of_the_requested_day():
    fixture_bytes = FIXTURE.read_bytes()
    session = FakeSession(fixture_bytes)

    result = eco2mix.fetch(date(2024, 3, 31), session=session)

    assert result == fixture_bytes  # raw CSV returned unchanged
    assert session.params == {
        "where": "date_heure >= '2024-03-31T00:00:00Z' and date_heure < '2024-04-01T00:00:00Z'",
        "order_by": "date_heure",
        "timezone": "UTC",
    }
