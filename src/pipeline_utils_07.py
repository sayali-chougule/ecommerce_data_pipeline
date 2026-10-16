from pathlib import Path


REQUIRED_DB_VARIABLES = (
    "PGHOST",
    "PGPORT",
    "PGDATABASE",
    "PGUSER",
    "PGPASSWORD",
)


def validate_db_config(config):
    """
    Validate PostgreSQL environment configuration.

    Args:
        config: Dictionary-like environment settings.

    Returns:
        Dictionary containing validated connection settings.

    Raises:
        ValueError: If required settings are missing or invalid.
    """
    missing = [
        name
        for name in REQUIRED_DB_VARIABLES
        if not str(config.get(name, "")).strip()
    ]

    if missing:
        raise ValueError(
            "Missing PostgreSQL configuration: "
            + ", ".join(missing)
        )

    try:
        port = int(config["PGPORT"])
    except (TypeError, ValueError):
        raise ValueError(
            "PGPORT must be a valid integer"
        ) from None

    if not 1 <= port <= 65535:
        raise ValueError(
            "PGPORT must be between 1 and 65535"
        )

    return {
        "host": config["PGHOST"],
        "port": port,
        "dbname": config["PGDATABASE"],
        "user": config["PGUSER"],
        "password": config["PGPASSWORD"],
    }


def validate_required_files(paths):
    """
    Raise FileNotFoundError if any required file is absent.
    """
    missing = [
        str(path)
        for path in paths
        if not Path(path).is_file()
    ]

    if missing:
        raise FileNotFoundError(
            "Required pipeline files not found: "
            + ", ".join(missing)
        )


def format_duration(seconds):
    """
    Format elapsed time for pipeline logs.
    """
    if seconds < 0:
        raise ValueError(
            "Duration cannot be negative"
        )

    return f"{seconds:.2f}s"