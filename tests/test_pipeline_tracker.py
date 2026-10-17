
import sys
from pathlib import Path
from unittest.mock import patch

import pytest


PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(
    0,
    str(PROJECT_ROOT / "src")
)

from pipeline_tracker_08 import PipelineTracker


def test_tracker_start_pipeline():
    tracker = PipelineTracker(
        db_config={"dbname": "test"}
    )

    with patch.object(
        tracker,
        "_execute"
    ) as mock_execute:

        tracker.start_pipeline(
            "example-pipeline-id"
        )

        mock_execute.assert_called_once()

        sql, params = mock_execute.call_args.args

        assert "INSERT INTO etl.pipeline_runs" in sql
        assert params == (
            "example-pipeline-id",
        )


def test_tracker_finish_pipeline():
    tracker = PipelineTracker(
        db_config={"dbname": "test"}
    )

    with patch.object(
        tracker,
        "_execute"
    ) as mock_execute:

        tracker.finish_pipeline(
            "example-pipeline-id",
            "FAILED",
            "Example error",
        )

        mock_execute.assert_called_once()

        sql, params = mock_execute.call_args.args

        assert "UPDATE etl.pipeline_runs" in sql
        assert params == (
            "FAILED",
            "Example error",
            "example-pipeline-id",
        )


def test_tracker_start_step():
    tracker = PipelineTracker(
        db_config={"dbname": "test"}
    )

    with patch.object(
        tracker,
        "_execute"
    ) as mock_execute:

        tracker.start_step(
            "example-pipeline-id",
            1,
            "Bronze ingestion",
        )

        mock_execute.assert_called_once()

        sql, params = mock_execute.call_args.args

        assert "INSERT INTO etl.pipeline_step_runs" in sql
        assert params == (
            "example-pipeline-id",
            1,
            "Bronze ingestion",
        )


def test_tracker_finish_step():
    tracker = PipelineTracker(
        db_config={"dbname": "test"}
    )

    with patch.object(
        tracker,
        "_execute"
    ) as mock_execute:

        tracker.finish_step(
            "example-pipeline-id",
            1,
            "FAILED",
            1.25,
            exit_code=99,
            error_message="Controlled test failure",
        )

        mock_execute.assert_called_once()

        sql, params = mock_execute.call_args.args

        assert "UPDATE etl.pipeline_step_runs" in sql
        assert params == (
            "FAILED",
            1.25,
            99,
            "Controlled test failure",
            "example-pipeline-id",
            1,
        )
