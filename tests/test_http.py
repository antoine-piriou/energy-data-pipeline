import logging

from energy_pipeline import http


class FakeResponse:
    def __init__(self, status_code, content=b""):
        self.status_code = status_code
        self.content = content


class FakeSession:
    """Return the given responses in order, one per get() call."""

    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = 0

    def get(self, url, params=None, timeout=None):
        self.calls += 1
        return self.responses.pop(0)


def test_retry_after_5xx_then_success(caplog):
    session = FakeSession([FakeResponse(503), FakeResponse(200, b"ok")])
    delays = []

    with caplog.at_level(logging.WARNING, logger="energy_pipeline.http"):
        body = http.get("https://example.test", session=session, sleep=delays.append)

    assert body == b"ok"
    assert session.calls == 2
    assert delays == [1.0]  # waited once, first backoff step
    warnings = [r for r in caplog.records if r.levelno == logging.WARNING]
    assert len(warnings) == 1
    assert "HTTP 503" in warnings[0].getMessage()
