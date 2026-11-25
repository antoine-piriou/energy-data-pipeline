from datetime import date

import pytest

from energy_pipeline import cli


def test_date_range():
    assert cli.date_range(date(2024, 2, 28), date(2024, 2, 28)) == [date(2024, 2, 28)]
    expected = [date(2024, 2, 28), date(2024, 2, 29), date(2024, 3, 1), date(2024, 3, 2)]
    assert cli.date_range(date(2024, 2, 28), date(2024, 3, 2)) == expected


def test_date_range_inverted():
    with pytest.raises(ValueError, match=".*is after.*"):
        cli.date_range(date(2024, 3, 2), date(2024, 2, 28))


# --- ingest: fake fetch, no network ---------------------------------------


def make_fake_fetch(monkeypatch, body):
    """Replace eco2mix.fetch with a fake; return the list of requested days."""
    calls = []

    def fake_fetch(day):
        calls.append(day)
        return body

    monkeypatch.setattr(cli.eco2mix, "fetch", fake_fetch)
    return calls


def test_ingest_is_idempotent(tmp_path, monkeypatch):
    calls = make_fake_fetch(monkeypatch, b"raw")
    start, end = date(2024, 1, 1), date(2024, 1, 3)

    first = cli.ingest("eco2mix", start, end, root=tmp_path)
    files_after_first = sorted(tmp_path.rglob("*"))
    second = cli.ingest("eco2mix", start, end, root=tmp_path)

    assert first == {"written": 3, "skipped": 0, "failed": 0}
    assert second == {"written": 0, "skipped": 3, "failed": 0}
    assert len(calls) == 3  # second run made no fetch at all
    assert sorted(tmp_path.rglob("*")) == files_after_first


def test_ingest_force_rewrites(tmp_path, monkeypatch):
    day = date(2024, 1, 1)
    make_fake_fetch(monkeypatch, b"old")
    cli.ingest("eco2mix", day, day, root=tmp_path)

    make_fake_fetch(monkeypatch, b"new")
    counts = cli.ingest("eco2mix", day, day, root=tmp_path, force=True)

    path = tmp_path / "source=eco2mix" / "date=2024-01-01" / "data.csv"
    assert counts["written"] == 1
    assert path.read_bytes() == b"new"
