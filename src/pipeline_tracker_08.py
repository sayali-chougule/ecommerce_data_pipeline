import os

import psycopg


class PipelineTracker:
    """
    Persist pipeline and step execution metadata.

    Each method commits its own metadata transaction.
    """

    def __init__(self, db_config=None):
        self.db_config = db_config or {
            "host": os.getenv("PGHOST", "localhost"),
            "port": os.getenv("PGPORT", "5432"),
            "dbname": os.getenv("PGDATABASE", "ecommerce_dw"),
            "user": os.getenv("PGUSER"),
            "password": os.getenv("PGPASSWORD"),
        }

    def _execute(self, sql, params):
        with psycopg.connect(**self.db_config) as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)

    def start_pipeline(self, pipeline_id):
        self._execute(
            """
            INSERT INTO etl.pipeline_runs (
                pipeline_id,
                status
            )
            VALUES (%s, 'RUNNING')
            """,
            (pipeline_id,),
        )

    def finish_pipeline(
        self,
        pipeline_id,
        status,
        error_message=None
    ):
        self._execute(
            """
            UPDATE etl.pipeline_runs
            SET status = %s,
                completed_at = NOW(),
                error_message = %s
            WHERE pipeline_id = %s
            """,
            (
                status,
                error_message,
                pipeline_id,
            ),
        )

    def start_step(
        self,
        pipeline_id,
        step_number,
        step_name
    ):
        self._execute(
            """
            INSERT INTO etl.pipeline_step_runs (
                pipeline_id,
                step_number,
                step_name,
                status
            )
            VALUES (%s, %s, %s, 'RUNNING')
            """,
            (
                pipeline_id,
                step_number,
                step_name,
            ),
        )

    def finish_step(
        self,
        pipeline_id,
        step_number,
        status,
        duration_seconds,
        exit_code=None,
        error_message=None
    ):
        self._execute(
            """
            UPDATE etl.pipeline_step_runs
            SET status = %s,
                completed_at = NOW(),
                duration_seconds = %s,
                exit_code = %s,
                error_message = %s
            WHERE pipeline_id = %s
              AND step_number = %s
            """,
            (
                status,
                duration_seconds,
                exit_code,
                error_message,
                pipeline_id,
                step_number,
            ),
        )