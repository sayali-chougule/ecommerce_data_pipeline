
import logging
import os
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

from dotenv import load_dotenv

from pipeline_utils_07 import (
    validate_db_config,
    validate_required_files,
)


# --------------------------------------------------
# Project configuration
# --------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = PROJECT_ROOT / "src"
SQL_DIR = PROJECT_ROOT / "sql"
LOG_DIR = PROJECT_ROOT / "logs"

LOG_DIR.mkdir(parents=True, exist_ok=True)

load_dotenv(PROJECT_ROOT / ".env")

PIPELINE_ID = str(uuid.uuid4())


# --------------------------------------------------
# Logging
# --------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(
            LOG_DIR / "pipeline.log"
        ),
    ],
)

logger = logging.getLogger(__name__)


# --------------------------------------------------
# Execute one pipeline step
# --------------------------------------------------

def run_step(step_name, command):
    logger.info("START | %s", step_name)

    started_at = time.monotonic()

    result = subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        env=os.environ.copy(),
        check=False,
    )

    duration = time.monotonic() - started_at

    if result.returncode != 0:
        logger.error(
            "FAILED | %s | exit_code=%s | duration=%.2fs",
            step_name,
            result.returncode,
            duration,
        )

        raise RuntimeError(
            f"Step failed: {step_name} "
            f"(exit code {result.returncode})"
        )

    logger.info(
        "SUCCESS | %s | duration=%.2fs",
        step_name,
        duration,
    )


# --------------------------------------------------
# Main pipeline
# --------------------------------------------------

def main():
    logger.info("=" * 55)
    logger.info("PIPELINE START | id=%s", PIPELINE_ID)
    logger.info("=" * 55)

    pipeline_start = time.monotonic()


    # Validate configuration before modifying any data.
    validate_db_config(os.environ)

    # Confirm the required pipeline files exist.
    validate_required_files([
        SRC_DIR / "03-load_bronze.py",
        SRC_DIR / "04-run_data_quality.py",
        SRC_DIR / "06-run_gold_quality.py",
        SQL_DIR / "06-transform_silver.sql",
        SQL_DIR / "10-transform_gold.sql",
        SQL_DIR / "12-create_gold_views.sql",
        SQL_DIR / "14-gold_quality_checks.sql",
    ])


    psql_path = shutil.which("psql")

    if psql_path is None:
        raise RuntimeError(
            "psql was not found on PATH. "
            "Verify your PostgreSQL CLI installation."
        )

    database_name = os.getenv(
        "PGDATABASE",
        "ecommerce_dw",
    )

    try:
        # STEP 1: Bronze ingestion
        run_step(
            "Bronze ingestion",
            [
                sys.executable,
                str(SRC_DIR / "03-load_bronze.py"),
            ],
        )

        # STEP 2: Source data quality
        run_step(
            "Pre-transformation validation",
            [
                sys.executable,
                str(SRC_DIR / "04-run_data_quality.py"),
                "--phase",
                "pre",
            ],
        )

        # STEP 3: Silver transformation
        run_step(
            "Silver transformation",
            [
                psql_path,
                "-X",
                "-v",
                "ON_ERROR_STOP=1",
                "-d",
                database_name,
                "-f",
                str(SQL_DIR / "06-transform_silver.sql"),
            ],
        )

        # STEP 4: Destination data quality
        run_step(
            "Post-transformation validation",
            [
                sys.executable,
                str(SRC_DIR / "04-run_data_quality.py"),
                "--phase",
                "post",
            ],
        )


        # STEP 5: Gold transformation
        run_step(
            "Gold transformation",
            [
                psql_path,
                "-X",
                "-v",
                "ON_ERROR_STOP=1",
                "-d",
                database_name,
                "-f",
                str(SQL_DIR / "10-transform_gold.sql"),
            ],
        )

        # STEP 6: Create or update analytical views
        run_step(
            "Gold analytical views",
            [
                psql_path,
                "-X",
                "-v",
                "ON_ERROR_STOP=1",
                "-d",
                database_name,
                "-f",
                str(SQL_DIR / "12-create_gold_views.sql"),
            ],
        )

        # STEP 7: Gold data quality
        run_step(
            "Gold validation",
            [
                sys.executable,
                str(SRC_DIR / "06-run_gold_quality.py"),
            ],
        )

    except Exception:
        duration = time.monotonic() - pipeline_start

        logger.exception(
            "PIPELINE FAILED | id=%s | duration=%.2fs",
            PIPELINE_ID,
            duration,
        )

        raise SystemExit(1)

    duration = time.monotonic() - pipeline_start

    logger.info("=" * 55)
    logger.info(
        "PIPELINE SUCCESS | id=%s | duration=%.2fs",
        PIPELINE_ID,
        duration,
    )
    logger.info("=" * 55)


if __name__ == "__main__":
    main()