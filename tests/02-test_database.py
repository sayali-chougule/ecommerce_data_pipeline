import os
from pathlib import Path

import psycopg
import pytest
from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")


@pytest.fixture(scope="module")
def db_connection():
    if os.getenv("RUN_DB_TESTS") != "1":
        pytest.skip(
            "Set RUN_DB_TESTS=1 to run PostgreSQL integration tests"
        )

    config = {
        "host": os.getenv("PGHOST", "localhost"),
        "port": os.getenv("PGPORT", "5432"),
        "dbname": os.getenv("PGDATABASE", "ecommerce_dw"),
        "user": os.getenv("PGUSER"),
        "password": os.getenv("PGPASSWORD"),
    }

    with psycopg.connect(**config) as conn:
        # Enforce read-only behavior at the database
        # transaction level.
        with conn.cursor() as cur:
            cur.execute(
                "SET TRANSACTION READ ONLY"
            )

        yield conn

        conn.rollback()


@pytest.mark.integration
def test_nine_bronze_tables(db_connection):
    with db_connection.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'bronze'
              AND table_type = 'BASE TABLE'
            """
        )
        assert cur.fetchone()[0] == 9


@pytest.mark.integration
def test_nine_silver_tables(db_connection):
    with db_connection.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'silver'
              AND table_type = 'BASE TABLE'
            """
        )
        assert cur.fetchone()[0] == 9


@pytest.mark.integration
def test_four_gold_tables(db_connection):
    with db_connection.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = 'gold'
              AND table_type = 'BASE TABLE'
            """
        )
        assert cur.fetchone()[0] == 4


@pytest.mark.integration
def test_five_gold_views(db_connection):
    with db_connection.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*)
            FROM information_schema.views
            WHERE table_schema = 'gold'
            """
        )
        assert cur.fetchone()[0] == 5


@pytest.mark.integration
def test_silver_gold_fact_counts(db_connection):
    with db_connection.cursor() as cur:
        cur.execute(
            """
            SELECT
                (SELECT COUNT(*)
                 FROM silver.order_items),

                (SELECT COUNT(*)
                 FROM gold.fact_order_items)
            """
        )

        silver_count, gold_count = cur.fetchone()

        assert silver_count == gold_count
        assert gold_count > 0


@pytest.mark.integration
def test_gold_fact_unique_grain(db_connection):
    with db_connection.cursor() as cur:
        cur.execute(
            """
            SELECT
                COUNT(*),
                COUNT(
                    DISTINCT (order_id, order_item_id)
                )
            FROM gold.fact_order_items
            """
        )

        total_rows, unique_rows = cur.fetchone()

        assert total_rows == unique_rows