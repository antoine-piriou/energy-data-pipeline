"""Connection to PostgreSQL (psycopg 3)."""

import psycopg

from energy_pipeline.config import DbSettings, get_db_settings


def connect(settings: DbSettings | None = None) -> psycopg.Connection:
    """Open a connection to PostgreSQL.

    The parameters are passed one by one: no connection string holding the
    password is ever built, so none can end up in a log or a traceback.
    """
    s = settings or get_db_settings()
    return psycopg.connect(
        host=s.host,
        port=s.port,
        dbname=s.dbname,
        user=s.user,
        password=s.password,
    )
