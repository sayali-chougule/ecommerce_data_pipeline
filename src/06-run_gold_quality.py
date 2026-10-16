
import logging
import os
import sys
import uuid
from pathlib import Path

import psycopg
from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SQL_FILE = PROJECT_ROOT / "sql" / "14-gold_quality_checks.sql"
LOG_DIR = PROJECT_ROOT / "logs"

LOG_DIR.mkdir(parents=True, exist_ok=True)

load_dotenv(PROJECT_ROOT / ".env")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_DIR / "gold_quality.log"),
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


def main():
    run_id = uuid.uuid4()
    failed_checks = 0

    logger.info("Starting Gold quality run: %s", run_id)

    sql = SQL_FILE.read_text(encoding="utf-8")

    with psycopg.connect(
        **DB_CONFIG,
        autocommit=True
    ) as conn:

        # Persist the run record before executing checks.
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO etl.data_quality_runs (
                    run_id,
                    status
                )
                VALUES (%s, 'RUNNING')
                """,
                (run_id,),
            )

        try:
            # Execute checks and store results atomically.
            with conn.transaction():
                with conn.cursor() as cur:
                    cur.execute(sql)
                    results = cur.fetchall()

                    expected_checks = {
                        "gold_fact_row_count",
                        "gold_fact_grain_unique",
                        "gold_customer_dimension",
                        "gold_product_dimension",
                        "gold_seller_dimension",
                        "gold_monthly_value",
                        "gold_category_value",
                    }

                    actual_checks = [
                        row[0] for row in results
                    ]

                    if (
                        len(actual_checks) != len(expected_checks)
                        or set(actual_checks) != expected_checks
                    ):
                        raise ValueError(
                            "Gold quality SQL did not return "
                            "the seven expected checks."
                        )

                    for (
                        check_name,
                        dataset,
                        failed_count
                    ) in results:

                        status = (
                            "PASS"
                            if failed_count == 0
                            else "FAIL"
                        )

                        if status == "FAIL":
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
                                check_name,
                                dataset,
                                failed_count,
                                status,
                            ),
                        )

                        logger.info(
                            "%s | %s | failures=%s",
                            status,
                            check_name,
                            failed_count,
                        )

                    final_status = (
                        "PASS"
                        if failed_checks == 0
                        else "FAIL"
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

        except Exception as exc:
            # The failed transaction has rolled back.
            # Record the execution error separately.
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

            logger.exception(
                "Gold quality execution error"
            )
            raise

    logger.info(
        "Gold quality finished | run_id=%s | "
        "failed_checks=%s",
        run_id,
        failed_checks,
    )

    if failed_checks > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()