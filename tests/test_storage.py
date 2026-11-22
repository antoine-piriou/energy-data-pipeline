from datetime import date
from pathlib import Path

from energy_pipeline import storage


def test_partition_path():
    expected = Path("data/raw/source=eco2mix/date=2024-02-03/data.csv")
    assert storage.partition_path(Path("data/raw"), "eco2mix", date(2024, 2, 3), "csv") == expected

def test_write_partition_creates_file(tmp_path):
    written = storage.write_partition(b"a;b\n1;2\n", tmp_path, "eco2mix", date(2024, 1, 5), "csv")

    path = tmp_path / "source=eco2mix" / "date=2024-01-05" / "data.csv"
    assert written is True
    assert path.read_bytes() == b"a;b\n1;2\n"
    assert not path.with_suffix(".tmp").exists()  # temporary file was renamed
