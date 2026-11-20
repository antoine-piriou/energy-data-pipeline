"""Raw storage, partitioned by date: <root>/source=<source>/date=YYYY-MM-DD/data.<ext>"""

import os
from datetime import date
from pathlib import Path


def partition_path(root: Path, source: str, day: date, extension: str) -> Path:
    """Return the file path of one source and one day. Pure: does not touch the disk."""
    return root / f"source={source}" / f"date={day.isoformat()}" / f"data.{extension}"


def write_partition(
    data: bytes,
    root: Path,
    source: str,
    day: date,
    extension: str,
    *,
    force: bool = False,
) -> bool:
    """Write `data` to the partition of `source` and `day`. Return True if written.

    Idempotent: if the partition already exists, nothing is written (returns False),
    unless `force` is True.
    Atomic: data goes to a temporary file first, then is renamed with os.replace,
    so the final file is either absent or complete, never half-written.
    """
    path = partition_path(root, source, day, extension)
    if path.exists() and not force:
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_path = path.with_suffix(".tmp")
    tmp_path.write_bytes(data)
    os.replace(tmp_path, path)
    return True
