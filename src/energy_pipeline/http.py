"""HTTP GET with timeout and retries (exponential backoff).

Retried: network errors (connection, timeout) and 5xx responses.
Not retried: 4xx responses (our request is wrong, retrying will not help).

Security: never log the full URL or query parameters, they may contain the
ENTSO-E token. Log only the base URL passed by the caller.
"""

import logging
import time
from collections.abc import Callable

import requests

logger = logging.getLogger(__name__)


class HttpError(Exception):
    """Raised when a request fails for good (4xx, or retries exhausted)."""


def get(
    url: str,
    params: dict | None = None,
    *,
    session: requests.Session | None = None,
    retries: int = 3,
    backoff: float = 1.0,
    timeout: float = 30.0,
    sleep: Callable[[float], None] = time.sleep,
) -> bytes:
    """GET `url` and return the raw response body.

    `session` and `sleep` are injectable so tests run without network or waiting.
    """
    session = session or requests.Session()
    attempts = retries + 1

    for attempt in range(1, attempts + 1):
        # Send the request
        try:
            response = session.get(url, params=params, timeout=timeout)
        except (requests.ConnectionError, requests.Timeout) as exc:
            reason = type(exc).__name__
        else:
            # Server answered: decide on the status code
            if response.status_code < 400:
                return response.content
            elif response.status_code < 500:
                raise HttpError(f"HTTP {response.status_code} for {url}")
            else:
                reason = f"HTTP {response.status_code}"

        # Last attempt: give up
        if attempt == attempts:
            logger.error("GET %s failed after %d attempts (%s)", url, attempts, reason)
            raise HttpError(f"GET {url} failed after {attempts} attempts ({reason})")

        # Otherwise: warn, wait, retry
        delay = backoff * 2 ** (attempt - 1)
        logger.warning(
            "GET %s failed (%s), attempt %d/%d, retrying in %.1fs",
            url,
            reason,
            attempt,
            attempts,
            delay,
        )
        sleep(delay)

    raise AssertionError("unreachable")  # the loop always returns or raises
