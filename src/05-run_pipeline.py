
import logging
import os
import shutil
import subprocess
import sys
import time
import uuid

from pathlib import Path

from dotenv import load_dotenv

from pipeline_tracker_08 import PipelineTracker
from pipeline_utils_07 import (
    validate_db_config,
    validate_required_files,
)


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = PROJECT_ROOT / "src"
SQL_DIR = PROJECT_ROOT / "sql"
LOG_DIR = PROJECT_ROOT / "logs"

LOG_DIR.mkdir(parents=True, exist_ok=True)

load_dotenv(PROJECT_ROOT / ".env")

PIPELINE_ID = str(uuid.uuid4())


logging.basicConfig(
    level=logging.INFO,
    format=(
        "%(asctime)s | %(levelname)s | "
        "%(message)s"
    ),
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_DIR / "pipeline.log"),
    ],
)

logger = logging.getLogger(__name__)


def run_step(
    tracker,
    step_number,
    step_name,
    command
):
    """
    Execute one pipeline step and persist its outcome.
    """

    # Safe failure simulation for observability testing.
    if (
        os.getenv("SIMULATE_PIPELINE_FAILURE") == "1"
        and step_number == 1
    ):
        logger.warning(
            "Simulating a failure before Bronze ingestion"
        )

        tracker.start_step(
            PIPELINE_ID,
            step_number,
            step_name,
        )

        tracker.finish_step(
            PIPELINE_ID,
            step_number,
            "FAILED",
            duration_seconds=0,
            exit_code=99,
            error_message="Controlled test failure",
        )

        raise RuntimeError(
            "Controlled test failure"
        )

    logger.info(
        "STEP START | pipeline_id=%s | step=%s | name=%s",
        PIPELINE_ID,
        step_number,
        step_name,
    )

    tracker.start_step(
        PIPELINE_ID,
        step_number,
        step_name,
    )

    started_at = time.monotonic()

    try:
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            env=os.environ.copy(),
            check=False,
        )

        duration = time.monotonic() - started_at

        if result.returncode != 0:
            error_message = (
                f"Step '{step_name}' returned "
                f"exit code {result.returncode}"
            )

            tracker.finish_step(
                PIPELINE_ID,
                step_number,
                "FAILED",
                duration,
                exit_code=result.returncode,
                error_message=error_message,
            )

            logger.error(
                "STEP FAILED | pipeline_id=%s | "
                "step=%s | exit_code=%s | duration=%.2fs",
                PIPELINE_ID,
                step_number,
                result.returncode,
                duration,
            )

            raise RuntimeError(error_message)

        tracker.finish_step(
            PIPELINE_ID,
            step_number,
            "SUCCESS",
            duration,
            exit_code=0,
        )

        logger.info(
            "STEP SUCCESS | pipeline_id=%s | "
            "step=%s | duration=%.2fs",
            PIPELINE_ID,
            step_number,
            duration,
        )

    except OSError as exc:
        duration = time.monotonic() - started_at

        tracker.finish_step(
            PIPELINE_ID,
            step_number,
            "FAILED",
            duration,
            error_message=str(exc),
        )

        logger.exception(
            "STEP EXECUTION ERROR | pipeline_id=%s | "
            "step=%s",
            PIPELINE_ID,
            step_number,
        )

        raise


def main():
    pipeline_start = time.monotonic()

    logger.info("=" * 60)
    logger.info(
        "PIPELINE START | id=%s",
        PIPELINE_ID,
    )
    logger.info("=" * 60)

    tracker = None
    tracking_started = False

    try:
        db_config = validate_db_config(os.environ)

        psql_path = shutil.which("psql")

        if psql_path is None:
            raise RuntimeError(
                "psql was not found on PATH."
            )

        database_name = db_config["dbname"]

        steps = [
            (
                "Bronze ingestion",
                [
                    sys.executable,
                    str(SRC_DIR / "03-load_bronze.py"),
                ],
            ),
            (
                "Pre-transformation validation",
                [
                    sys.executable,
                    str(SRC_DIR / "04-run_data_quality.py"),
                    "--phase",
                    "pre",
                ],
            ),
            (
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
            ),
            (
                "Post-transformation validation",
                [
                    sys.executable,
                    str(SRC_DIR / "04-run_data_quality.py"),
                    "--phase",
                    "post",
                ],
            ),
            (
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
            ),
            (
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
            ),
            (
                "Gold validation",
                [
                    sys.executable,
                    str(SRC_DIR / "06-run_gold_quality.py"),
                ],
            ),
        ]

        validate_required_files([
            str(SRC_DIR / "03-load_bronze.py"),
            str(SRC_DIR / "04-run_data_quality.py"),
            str(SRC_DIR / "06-run_gold_quality.py"),
            str(SQL_DIR / "06-transform_silver.sql"),
            str(SQL_DIR / "10-transform_gold.sql"),
            str(SQL_DIR / "12-create_gold_views.sql"),
            str(SQL_DIR / "14-gold_quality_checks.sql"),
        ])

        tracker = PipelineTracker(db_config)
        tracker.start_pipeline(PIPELINE_ID)
        tracking_started = True

        for step_number, (
            step_name,
            command
        ) in enumerate(steps, start=1):

            run_step(
                tracker,
                step_number,
                step_name,
                command,
            )

        tracker.finish_pipeline(
            PIPELINE_ID,
            "SUCCESS",
        )

        duration = time.monotonic() - pipeline_start

        logger.info("=" * 60)
        logger.info(
            "PIPELINE SUCCESS | id=%s | duration=%.2fs",
            PIPELINE_ID,
            duration,
        )
        logger.info("=" * 60)

    except Exception as exc:
        duration = time.monotonic() - pipeline_start

        if tracker is not None and tracking_started:
            try:
                tracker.finish_pipeline(
                    PIPELINE_ID,
                    "FAILED",
                    error_message=str(exc),
                )
            except Exception:
                logger.exception(
                    "Unable to persist pipeline failure"
                )

        logger.exception(
            "PIPELINE FAILED | id=%s | duration=%.2fs",
            PIPELINE_ID,
            duration,
        )

        raise SystemExit(1)


if __name__ == "__main__":
    main()