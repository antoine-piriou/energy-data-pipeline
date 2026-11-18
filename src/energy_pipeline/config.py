"""Settings read from the environment (or a local .env file, never committed)."""

import os
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
