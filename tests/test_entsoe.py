import logging
from datetime import date

import pytest

from energy_pipeline.logging_setup import setup_logging
from energy_pipeline.sources import entsoe


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


def test_fetch_without_token_fails_clearly(monkeypatch):
    # The real .env was already loaded at import: remove the variable for this test only
    monkeypatch.delenv("ENTSOE_API_TOKEN", raising=False)

    # No session needed: the token is checked before any network call
    with pytest.raises(RuntimeError, match="ENTSOE_API_TOKEN"):
        entsoe.fetch(date(2024, 3, 31))


def test_fetch_sends_token_and_utc_period(monkeypatch):
    # A fake token: the real one must never appear in tests
    monkeypatch.setenv("ENTSOE_API_TOKEN", "fake-token")
    session = FakeSession(b"<xml/>")

    result = entsoe.fetch(date(2024, 3, 31), session=session)

    assert result == b"<xml/>"
    assert session.params["securityToken"] == "fake-token"
    assert session.params["periodStart"] == "202403310000"
    assert session.params["periodEnd"] == "202404010000"  # next day, excluded


def test_debug_logging_keeps_urllib3_quiet():
    # urllib3 logs full URLs (token included) at DEBUG: it must stay at WARNING
    setup_logging("DEBUG")
    assert logging.getLogger("urllib3").getEffectiveLevel() == logging.WARNING
