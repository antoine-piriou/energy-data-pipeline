"""Settings read from the environment (or a local .env file, never committed)."""

import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

RAW_DATA_DIR = Path(os.getenv("RAW_DATA_DIR", "data/raw"))


def get_entsoe_token() -> str:
    """Return the ENTSO-E API token, or raise a clear error if it is missing.

    The token must never appear in logs or error messages.
    """
    token = os.getenv("ENTSOE_API_TOKEN")
    if not token:
        raise RuntimeError(
            "ENTSOE_API_TOKEN is not set. Copy .env.example to .env and fill in your token."
        )
    return token


@dataclass(frozen=True)
class DbSettings:
    """Everything needed to reach PostgreSQL."""

    host: str
    port: int
    dbname: str
    user: str
    # repr=False: printing or logging the settings never shows the password
    password: str = field(repr=False)


def get_db_settings() -> DbSettings:
    """Read the PostgreSQL settings, or raise a clear error if the password is missing.

    Read at call time (not import time), so a missing password only breaks the
    commands that need the database.
    """
    password = os.getenv("POSTGRES_PASSWORD")
    if not password:
        raise RuntimeError(
            "POSTGRES_PASSWORD is not set. Copy .env.example to .env and fill it in."
        )
    return DbSettings(
        host=os.getenv("POSTGRES_HOST", "127.0.0.1"),
        port=int(os.getenv("POSTGRES_PORT", "5433")),
        dbname=os.getenv("POSTGRES_DB", "energy"),
        user=os.getenv("POSTGRES_USER", "energy"),
        password=password,
    )
