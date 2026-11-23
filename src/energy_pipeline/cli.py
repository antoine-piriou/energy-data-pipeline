"""Command line entry point.

Usage:
    python -m energy_pipeline.cli ingest --source eco2mix --start 2024-01-01 --end 2024-01-07
"""

import argparse
import logging
import sys
from datetime import date, timedelta
from pathlib import Path
from types import ModuleType

from energy_pipeline import config, storage
from energy_pipeline.http import HttpError
from energy_pipeline.logging_setup import setup_logging
from energy_pipeline.sources import eco2mix, entsoe, open_meteo

logger = logging.getLogger(__name__)

# Each source module exposes fetch(day) -> bytes and EXTENSION.
SOURCES: dict[str, ModuleType] = {
    "eco2mix": eco2mix,
    "open_meteo": open_meteo,
    "entsoe": entsoe,
}


def date_range(start: date, end: date) -> list[date]:
    """Return every day from `start` to `end`, both included."""
    if start > end:
        raise ValueError(f"start ({start}) is after end ({end})")
    return [start + timedelta(days=i) for i in range((end - start).days + 1)]


def ingest(
    source: str,
    start: date,
    end: date,
    *,
    root: Path,
    force: bool = False,
) -> dict[str, int]:
    """Fetch and store one partition per day. Return counts of written, skipped, failed days.

    A failed day is logged and the run goes on, so one bad day does not block the others.
    Rerunning the same command only fetches the days that are still missing.
    """
    module = SOURCES[source]
    counts = {"written": 0, "skipped": 0, "failed": 0}

    for day in date_range(start, end):
        path = storage.partition_path(root, source, day, module.EXTENSION)
        if path.exists() and not force:
            logger.info("%s %s: already present, skipped", source, day)
            counts["skipped"] += 1
            continue

        try:
            data = module.fetch(day)
        except HttpError as exc:
            logger.error("%s %s: fetch failed (%s)", source, day, exc)
            counts["failed"] += 1
            continue

        storage.write_partition(data, root, source, day, module.EXTENSION, force=force)
        logger.info("%s %s: written (%d bytes)", source, day, len(data))
        counts["written"] += 1

    logger.info(
        "%s %s to %s: %d written, %d skipped, %d failed",
        source,
        start,
        end,
        counts["written"],
        counts["skipped"],
        counts["failed"],
    )
    return counts


def build_parser() -> argparse.ArgumentParser:
    """Define the command line arguments."""
    parser = argparse.ArgumentParser(prog="energy_pipeline")
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING"])
    commands = parser.add_subparsers(dest="command", required=True)

    ingest_cmd = commands.add_parser("ingest", help="download raw data, one file per day")
    ingest_cmd.add_argument("--source", required=True, choices=sorted(SOURCES))
    ingest_cmd.add_argument("--start", required=True, type=date.fromisoformat, help="YYYY-MM-DD")
    ingest_cmd.add_argument("--end", required=True, type=date.fromisoformat, help="YYYY-MM-DD")
    ingest_cmd.add_argument("--force", action="store_true", help="rewrite existing partitions")
    ingest_cmd.add_argument("--root", type=Path, default=config.RAW_DATA_DIR)
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the command line. Return the exit code: 0 if every day succeeded, 1 otherwise."""
    args = build_parser().parse_args(argv)
    setup_logging(args.log_level)

    try:
        counts = ingest(args.source, args.start, args.end, root=args.root, force=args.force)
    except ValueError as exc:
        logger.error("%s", exc)
        return 1
    return 1 if counts["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
