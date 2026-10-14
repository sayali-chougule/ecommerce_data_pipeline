import logging
import os
import uuid
from pathlib import Path
import argparse

import psycopg
from dotenv import load_dotenv

# 1. Connect to PostgreSQL using your existing .env.

PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")

LOG_DIR = PROJECT_ROOT / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_DIR / "data_quality.log"),
    ],
)

logger = logging.getLogger(__name__)

DB_CONFIG = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": os.getenv("PGPORT", "5432"),
    "dbname": os.getenv("PGDATABASE", "ecommerce_dw"),
    "user": os.getenv("PGUSER"),
    "password": os.getenv("PGPASSWORD"),
}
# 2. Generate a unique run ID.
# Every query must return exactly one integer:
# the number of records or conditions that failed.
CHECKS = [
    {
        "name": "missing_customer_ids",
        "phase":"pre",
        "dataset": "bronze.customers",
        "sql": """
            SELECT COUNT(*)
            FROM bronze.customers
            WHERE NULLIF(TRIM(customer_id), '') IS NULL
        """,
    },
    {
        "name": "duplicate_order_ids",
        "phase":"pre",
        "dataset": "bronze.orders",
        "sql": """
            SELECT COALESCE(SUM(duplicate_count - 1), 0)
            FROM (
                SELECT COUNT(*) AS duplicate_count
                FROM bronze.orders
                GROUP BY NULLIF(TRIM(order_id), '')
                HAVING COUNT(*) > 1
            ) d
        """,
    },
    {
        "name": "invalid_item_prices",
        "phase":"pre",
        "dataset": "bronze.order_items",
        "sql": """
            SELECT COUNT(*)
            FROM bronze.order_items
            WHERE NULLIF(TRIM(price), '') IS NULL
               OR TRIM(price) !~ '^[0-9]+(\\.[0-9]+)?$'
               OR CASE
                    WHEN TRIM(price) ~ '^[0-9]+(\\.[0-9]+)?$'
                    THEN TRIM(price)::NUMERIC < 0
                    ELSE FALSE
                  END
        """,
        "rejection_sql": """
            SELECT to_jsonb(t)
            FROM bronze.order_items AS t
            WHERE NULLIF(TRIM(price), '') IS NULL
               OR TRIM(price) !~ '^[0-9]+(\\.[0-9]+)?$'
               OR CASE
                    WHEN TRIM(price) ~ '^[0-9]+(\\.[0-9]+)?$'
                    THEN TRIM(price)::NUMERIC < 0
                    ELSE FALSE
                  END
        """,
        "reason": "Price is missing, malformed, or negative",
    },
    {
        "name": "invalid_review_scores",
        "phase":"pre",
        "dataset": "bronze.reviews",
        "sql": """
            SELECT COUNT(*)
            FROM bronze.reviews
            WHERE NULLIF(TRIM(review_score), '') IS NULL
               OR TRIM(review_score) !~ '^[1-5]$'
        """,
        "rejection_sql": """
            SELECT to_jsonb(t)
            FROM bronze.reviews AS t
            WHERE NULLIF(TRIM(review_score), '') IS NULL
               OR TRIM(review_score) !~ '^[1-5]$'
        """,
        "reason": "Review score must be an integer from 1 to 5",
    },
    {
        "name": "orphan_order_items",
        "phase":"pre",
        "dataset": "bronze.order_items",
        "sql": """
            SELECT COUNT(*)
            FROM bronze.order_items i
            WHERE NOT EXISTS (
                SELECT 1
                FROM bronze.orders o
                WHERE TRIM(o.order_id) = TRIM(i.order_id)
            )
        """,
    },
    {
        "name": "bronze_silver_count_mismatches",
        "phase":"post",
        "dataset": "all_silver_tables",
        "sql": """
            WITH counts AS (
                SELECT
                    (SELECT COUNT(*) FROM bronze.customers) AS b1,
                    (SELECT COUNT(*) FROM silver.customers) AS s1,
                    (SELECT COUNT(*) FROM bronze.orders) AS b2,
                    (SELECT COUNT(*) FROM silver.orders) AS s2,
                    (SELECT COUNT(*) FROM bronze.products) AS b3,
                    (SELECT COUNT(*) FROM silver.products) AS s3,
                    (SELECT COUNT(*) FROM bronze.sellers) AS b4,
                    (SELECT COUNT(*) FROM silver.sellers) AS s4,
                    (SELECT COUNT(*) FROM bronze.order_items) AS b5,
                    (SELECT COUNT(*) FROM silver.order_items) AS s5,
                    (SELECT COUNT(*) FROM bronze.payments) AS b6,
                    (SELECT COUNT(*) FROM silver.payments) AS s6,
                    (SELECT COUNT(*) FROM bronze.reviews) AS b7,
                    (SELECT COUNT(*) FROM silver.reviews) AS s7,
                    (SELECT COUNT(*) FROM bronze.geolocation) AS b8,
                    (SELECT COUNT(*) FROM silver.geolocation) AS s8,
                    (SELECT COUNT(*) FROM bronze.product_category_translation) AS b9,
                    (SELECT COUNT(*) FROM silver.product_category_translation) AS s9
            )
            SELECT
                (b1 <> s1)::INT +
                (b2 <> s2)::INT +
                (b3 <> s3)::INT +
                (b4 <> s4)::INT +
                (b5 <> s5)::INT +
                (b6 <> s6)::INT +
                (b7 <> s7)::INT +
                (b8 <> s8)::INT +
                (b9 <> s9)::INT
            FROM counts
        """,
    },
]


def record_rejections(cur, run_id, check):
    """Store individual invalid source records as JSONB."""
    if "rejection_sql" not in check:
        return 0

    cur.execute(check["rejection_sql"])
    records = cur.fetchall()

    for (record_data,) in records:
        cur.execute(
            """
            INSERT INTO etl.rejected_records (
                run_id,
                source_table,
                check_name,
                rejection_reason,
                record_data
            )
            VALUES (%s, %s, %s, %s, %s::jsonb)
            """,
            (
                run_id,
                check["dataset"],
                check["name"],
                check["reason"],
                psycopg.types.json.Jsonb(record_data),
            ),
        )

    return len(records)


def main():
    parser = argparse.ArgumentParser(
        description="Run Olist data quality checks"
    )

    parser.add_argument(
        "--phase",
        choices=["pre", "post", "all"],
        default="all",
        help="Which validation phase to execute",
    )

    args = parser.parse_args()

    selected_checks = [
        check
        for check in CHECKS
        if args.phase == "all"
        or check["phase"] == args.phase
    ]

    run_id = uuid.uuid4()
    failed_checks = 0

    logger.info("Starting data quality run: %s", run_id)

    with psycopg.connect(**DB_CONFIG, autocommit=True) as conn:

        # Persist the RUNNING record before executing checks.
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO etl.data_quality_runs (run_id, status)
                VALUES (%s, 'RUNNING')
                """,
                (run_id,),
            )
        conn.commit()

        try:
            # All results and rejections are written together.
            with conn.transaction():
                with conn.cursor() as cur:

                    for check in selected_checks:
                        cur.execute(check["sql"])
                        failed_count = cur.fetchone()[0]

                        status = (
                            "PASS" if failed_count == 0 else "FAIL"
                        )

                        if failed_count > 0:
                            failed_checks += 1

                        cur.execute(
                            """
                            INSERT INTO etl.data_quality_results (
                                run_id,
                                check_name,
                                dataset,
                                failed_count,
                                status
                            )
                            VALUES (%s, %s, %s, %s, %s)
                            """,
                            (
                                run_id,
                                check["name"],
                                check["dataset"],
                                failed_count,
                                status,
                            ),
                        )

                        if failed_count > 0:
                            quarantined = record_rejections(
                                cur, run_id, check
                            )
                            logger.warning(
                                "%s | %s | failures=%s | "
                                "quarantined=%s",
                                status,
                                check["name"],
                                failed_count,
                                quarantined,
                            )
                        else:
                            logger.info(
                                "PASS | %s", check["name"]
                            )

                    final_status = (
                        "PASS" if failed_checks == 0 else "FAIL"
                    )

                    cur.execute(
                        """
                        UPDATE etl.data_quality_runs
                        SET status = %s,
                            completed_at = NOW()
                        WHERE run_id = %s
                        """,
                        (final_status, run_id),
                    )

            logger.info(
                "Quality run finished | run_id=%s | status=%s",
                run_id,
                final_status,
            )

        except Exception as exc:
            conn.rollback()

            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE etl.data_quality_runs
                    SET status = 'ERROR',
                        completed_at = NOW(),
                        error_message = %s
                    WHERE run_id = %s
                    """,
                    (str(exc), run_id),
                )
            conn.commit()

            logger.exception("Data quality execution error")
            raise

    if failed_checks > 0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()