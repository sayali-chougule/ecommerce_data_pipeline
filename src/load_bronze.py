import csv
import logging
import os
import uuid
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from psycopg import sql


# --------------------------------------------------
# 1. Project configuration
# --------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = PROJECT_ROOT / "data" / "extracted"
LOG_DIR = PROJECT_ROOT / "logs"

LOG_DIR.mkdir(parents=True, exist_ok=True)

load_dotenv(PROJECT_ROOT / ".env")

DB_CONFIG = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": os.getenv("PGPORT", "5432"),
    "dbname": os.getenv("PGDATABASE", "ecommerce_dw"),
    "user": os.getenv("PGUSER"),
    "password": os.getenv("PGPASSWORD") or None,
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "bronze_ingestion.log"),
        logging.StreamHandler(),
    ],
)

logger = logging.getLogger(__name__)


# --------------------------------------------------
# 2. Source-to-target mapping
# --------------------------------------------------

TABLE_MAPPING = {
    "olist_customers_dataset.csv": "customers",
    "olist_orders_dataset.csv": "orders",
    "olist_order_items_dataset.csv": "order_items",
    "olist_products_dataset.csv": "products",
    "olist_sellers_dataset.csv": "sellers",
    "olist_order_payments_dataset.csv": "payments",
    "olist_order_reviews_dataset.csv": "reviews",
    "olist_geolocation_dataset.csv": "geolocation",
    "product_category_name_translation.csv":
        "product_category_translation",
}


# --------------------------------------------------
# 3. Source validation
# --------------------------------------------------

def validate_source_file(file_path, expected_columns):
    if not file_path.is_file():
        raise FileNotFoundError(f"Missing file: {file_path}")

    with file_path.open(
        "r", encoding="utf-8-sig", newline=""
    ) as f:
        reader = csv.reader(f)
        header = next(reader, None)

        if header is None:
            raise ValueError(f"Empty CSV: {file_path.name}")

        if header != expected_columns:
            raise ValueError(
                f"Column mismatch in {file_path.name}\n"
                f"Expected: {expected_columns}\n"
                f"Actual:   {header}"
            )

        row_count = sum(1 for _ in reader)

    return row_count


# --------------------------------------------------
# 4. Read Bronze source column names
# --------------------------------------------------

def get_source_columns(conn, table_name):
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = 'bronze'
              AND table_name = %s
              AND column_name NOT IN (
                  'batch_id',
                  'source_file',
                  'ingested_at'
              )
            ORDER BY ordinal_position
            """,
            (table_name,),
        )
        columns = [row[0] for row in cur.fetchall()]

    if not columns:
        raise ValueError(
            f"No source columns found for bronze.{table_name}"
        )

    return columns


# --------------------------------------------------
# 5. Audit helpers
# --------------------------------------------------

def create_batch(conn, batch_id, filename, table_name):
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO etl.ingestion_batches (
                batch_id,
                source_file,
                target_table,
                status
            )
            VALUES (%s, %s, %s, 'RUNNING')
            """,
            (
                batch_id,
                filename,
                f"bronze.{table_name}",
            ),
        )
    conn.commit()


def finish_batch(conn, batch_id, status, rows, error=None):
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE etl.ingestion_batches
            SET status = %s,
                rows_loaded = %s,
                completed_at = NOW(),
                error_message = %s
            WHERE batch_id = %s
            """,
            (status, rows, error, batch_id),
        )
    conn.commit()


# --------------------------------------------------
# 6. Load one CSV using PostgreSQL COPY
# --------------------------------------------------

def load_table(conn, filename, table_name):
    file_path = RAW_DIR / filename
    batch_id = uuid.uuid4()

    logger.info("Starting %s -> bronze.%s", filename, table_name)

    create_batch(conn, batch_id, filename, table_name)

    try:
        columns = get_source_columns(conn, table_name)
        source_count = validate_source_file(
            file_path, columns
        )

        # One transaction per table:
        # old data is replaced only if COPY and
        # validation both succeed.
        with conn.transaction():
            with conn.cursor() as cur:
                cur.execute(
                    sql.SQL("TRUNCATE TABLE {}").format(
                        sql.Identifier("bronze", table_name)
                    )
                )

                copy_statement = sql.SQL(
                    "COPY {} ({}) "
                    "FROM STDIN WITH (FORMAT CSV, HEADER TRUE)"
                ).format(
                    sql.Identifier("bronze", table_name),
                    sql.SQL(", ").join(
                        sql.Identifier(col) for col in columns
                    ),
                )

                with file_path.open("rb") as source:
                    with cur.copy(copy_statement) as copy:
                        while chunk := source.read(1024 * 1024):
                            copy.write(chunk)

                cur.execute(
                    sql.SQL(
                        """
                        UPDATE {}
                        SET batch_id = %s,
                            source_file = %s,
                            ingested_at = NOW()
                        """
                    ).format(
                        sql.Identifier("bronze", table_name)
                    ),
                    (batch_id, filename),
                )

                cur.execute(
                    sql.SQL("SELECT COUNT(*) FROM {}").format(
                        sql.Identifier("bronze", table_name)
                    )
                )

                db_count = cur.fetchone()[0]

                if db_count != source_count:
                    raise ValueError(
                        f"Row count mismatch: "
                        f"CSV={source_count}, DB={db_count}"
                    )

        finish_batch(
            conn, batch_id, "SUCCESS", db_count
        )

        logger.info(
            "SUCCESS | %s | rows=%s | batch=%s",
            table_name, db_count, batch_id
        )

    except Exception as exc:
        # Transaction rollback restores the previous
        # table contents if loading failed.
        conn.rollback()

        finish_batch(
            conn, batch_id, "FAILED", 0, str(exc)
        )

        logger.exception(
            "FAILED | %s | batch=%s",
            table_name, batch_id
        )
        raise


# --------------------------------------------------
# 7. Main pipeline
# --------------------------------------------------

def main():
    logger.info("Starting Olist Bronze ingestion")

    # Preflight: all expected source files must exist.
    for filename in TABLE_MAPPING:
        if not (RAW_DIR / filename).is_file():
            raise FileNotFoundError(
                f"Required source file missing: {filename}"
            )

    with psycopg.connect(**DB_CONFIG) as conn:
        # Explicit transaction management is used
        # inside load_table().
        conn.autocommit = True

        for filename, table_name in TABLE_MAPPING.items():
            load_table(conn, filename, table_name)

    logger.info("All Bronze tables loaded successfully")


if __name__ == "__main__":
    main()