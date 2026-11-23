from datetime import date
from pathlib import Path

from energy_pipeline import cli
from energy_pipeline.sources import open_meteo

FIXTURE = Path(__file__).parent / "fixtures" / "open_meteo_sample.json"


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


def test_fetch_asks_for_one_day_of_paris_temperature():
    fixture_bytes = FIXTURE.read_bytes()
    session = FakeSession(fixture_bytes)

    result = open_meteo.fetch(date(2024, 3, 31), session=session)

    assert result == fixture_bytes  # raw JSON returned unchanged
    assert session.params == {
        "latitude": 48.8566,
        "longitude": 2.3522,
        "start_date": "2024-03-31",
        "end_date": "2024-03-31",  # end_date is included: same day
        "hourly": "temperature_2m",
        "timezone": "UTC",
    }


def test_ingest_writes_the_response_as_json(tmp_path, monkeypatch):
    fixture_bytes = FIXTURE.read_bytes()
    monkeypatch.setattr(cli.open_meteo, "fetch", lambda day: fixture_bytes)  # no network

    counts = cli.ingest("open_meteo", date(2024, 3, 31), date(2024, 3, 31), root=tmp_path)

    path = tmp_path / "source=open_meteo" / "date=2024-03-31" / "data.json"
    assert counts["written"] == 1
    assert path.read_bytes() == fixture_bytes
