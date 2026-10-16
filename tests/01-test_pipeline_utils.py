
import sys
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = PROJECT_ROOT / "src"

sys.path.insert(0, str(SRC_DIR))

from pipeline_utils_07 import (
    validate_db_config,
    validate_required_files,
    format_duration,
)


@pytest.fixture
def valid_config():
    return {
        "PGHOST": "localhost",
        "PGPORT": "5432",
        "PGDATABASE": "test_database",
        "PGUSER": "test_user",
        "PGPASSWORD": "test_password",
    }


def test_valid_database_config(valid_config):
    result = validate_db_config(valid_config)

    assert result["host"] == "localhost"
    assert result["port"] == 5432
    assert result["dbname"] == "test_database"


def test_missing_database_user(valid_config):
    del valid_config["PGUSER"]

    with pytest.raises(
        ValueError,
        match="PGUSER"
    ):
        validate_db_config(valid_config)


def test_invalid_database_port(valid_config):
    valid_config["PGPORT"] = "not_a_number"

    with pytest.raises(
        ValueError,
        match="PGPORT"
    ):
        validate_db_config(valid_config)


def test_out_of_range_database_port(valid_config):
    valid_config["PGPORT"] = "70000"

    with pytest.raises(
        ValueError,
        match="65535"
    ):
        validate_db_config(valid_config)


def test_existing_required_file(tmp_path):
    file_path = tmp_path / "example.sql"
    file_path.write_text(
        "SELECT 1;",
        encoding="utf-8"
    )

    validate_required_files([file_path])


def test_missing_required_file(tmp_path):
    missing_file = tmp_path / "missing.sql"

    with pytest.raises(
        FileNotFoundError,
        match="missing.sql"
    ):
        validate_required_files([missing_file])


def test_duration_formatting():
    assert format_duration(12.345) == "12.35s"


def test_negative_duration():
    with pytest.raises(ValueError):
        format_duration(-1)
