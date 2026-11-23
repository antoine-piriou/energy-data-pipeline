"""Logging configuration for the pipeline. Called once, by the CLI."""

import logging

LOG_FORMAT = "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S"


def setup_logging(level: str = "INFO") -> None:
    """Configure application logging. Must be called only once, at startup."""
    logging.basicConfig(level=level, format=LOG_FORMAT, datefmt=DATE_FORMAT)
    # urllib3 (used by requests) logs full URLs at DEBUG, query string included:
    # that would print the ENTSO-E token. Keep it at WARNING whatever our level.
    logging.getLogger("urllib3").setLevel(logging.WARNING)
