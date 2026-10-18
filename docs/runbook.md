# Operational Runbook — Olist E-commerce ELT Pipeline

## Purpose

This runbook covers local setup, execution, validation, troubleshooting, and recovery for the PostgreSQL ELT pipeline.

## Prerequisites

- macOS or a comparable development environment with Python 3.9-compatible tooling.
- PostgreSQL running locally, with `psql` available on `PATH`.
- The nine Olist CSV files extracted into `data/extract/`.
- A local `.env` created from `.env.example` with valid `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER`, and `PGPASSWORD` values.
- Python scripts and SQL files present in `src/` and `sql/`.

**Filename warning:** Some development versions of this project use numbered script names (for example, `src/04-run_data_quality.py`). Use the filenames that actually exist in your checkout; the commands below show the unnumbered names.

## 1. Activate and install

From the project root:

```bash
source .project1/bin/activate
python -m pip install -r requirements.txt
```

For a fresh environment, create it first:

```bash
python3 -m venv .project1
source .project1/bin/activate
python -m pip install -r requirements.txt
```

Create local configuration:

```bash
cp .env.example .env
```

Edit `.env` locally. Never commit it.

## 2. Check PostgreSQL

```bash
psql -d ecommerce_dw -c 'SELECT 1;'
```

If the database does not exist and your PostgreSQL account has permission:

```bash
createdb ecommerce_dw
```

**Note:** `psql` reads PostgreSQL environment variables such as `PGHOST` and `PGPASSWORD`; unlike Python, it does not automatically parse `.env`. Configure your shell or connection settings accordingly.

## 3. Initialize a new database

**Run these commands only for a fresh database after checking that the scripts exist.** Do not drop or recreate your working database to test documentation.

```bash
psql -d ecommerce_dw -v ON_ERROR_STOP=1 -f sql/02-create_bronze_tables.sql
psql -d ecommerce_dw -v ON_ERROR_STOP=1 -f sql/03-ingestion_metadata.sql
psql -d ecommerce_dw -v ON_ERROR_STOP=1 -f sql/04-create_silver_tables.sql
psql -d ecommerce_dw -v ON_ERROR_STOP=1 -f sql/08-data_quality_setup.sql
psql -d ecommerce_dw -v ON_ERROR_STOP=1 -f sql/09-create_gold_tables.sql
psql -d ecommerce_dw -v ON_ERROR_STOP=1 -f sql/15-pipeline_metadata.sql
```

The pipeline creates/replaces the Gold analytical views after the Gold transformation. If any DDL script assumes an object not yet created, inspect that script's dependencies before rerunning.

## 4. Execute the pipeline

```bash
python src/06-run_pipeline.py
```

Expected: seven successful steps followed by `PIPELINE SUCCESS`. The controller uses fail-fast behavior; it stops on a failed required step.

## 5. Run tests

Run unit tests (database integration tests are skipped unless enabled):

```bash
python -m pytest -v
```

Run all unit and read-only PostgreSQL integration tests:

```bash
RUN_DB_TESTS=1 python -m pytest -v
```

As of Stage 6B, the expected result is **18 passing tests**. Test counts should be updated when tests are added or removed.

## 6. Check the latest pipeline status

```sql
SELECT pipeline_id, status, started_at, completed_at, error_message
FROM etl.pipeline_runs
ORDER BY started_at DESC
LIMIT 10;
```

Check the steps of the latest run:

```sql
SELECT s.step_number, s.step_name, s.status,
       s.duration_seconds, s.exit_code, s.error_message
FROM etl.pipeline_step_runs s
WHERE s.pipeline_id = (
    SELECT pipeline_id
    FROM etl.pipeline_runs
    ORDER BY started_at DESC
    LIMIT 1
)
ORDER BY s.step_number;
```

Expected after a successful run: seven `SUCCESS` step rows.

## 7. Investigate quality failures

```sql
SELECT r.run_id, r.status AS run_status,
       q.check_name, q.dataset, q.failed_count,
       q.status AS check_status
FROM etl.data_quality_runs r
JOIN etl.data_quality_results q ON q.run_id = r.run_id
WHERE q.status = 'FAIL'
ORDER BY r.started_at DESC;
```

Inspect quarantined records:

```sql
SELECT source_table, check_name, rejection_reason, detected_at
FROM etl.rejected_records
ORDER BY detected_at DESC
LIMIT 20;
```

Also review `logs/pipeline.log`, `logs/bronze_ingestion.log`, `logs/data_quality.log`, and `logs/gold_quality.log` if those are the filenames in your checkout.

## 8. Troubleshooting

| Symptom | What to inspect | Typical action |
|---|---|---|
| Database connection refused | PostgreSQL process, host, port | Start PostgreSQL; check `.env` |
| Authentication failure | User/password, shell environment | Correct credentials; do not log secrets |
| `psql` not found | `command -v psql` | Add PostgreSQL binary directory to `PATH` |
| Required file missing | Script path, numbered filename | Update controller path to match file |
| Bronze load fails | Source CSVs, ingestion log | Fix missing/invalid source file and rerun |
| Silver transformation fails | SQL errors, source types/keys | Fix root cause; rerun full pipeline |
| Quality gate fails | `etl.data_quality_results` | Investigate failed check, not just counts |
| Tests collect zero items | `tests/test_*.py` naming | Rename tests or configure pytest discovery |
| Stale `RUNNING` record | Process termination, host crash | Investigate process/logs; do not assume still active |

## 9. Recovery procedure

1. Find the failed pipeline in `etl.pipeline_runs`.
2. Inspect the failed step in `etl.pipeline_step_runs`.
3. Read its corresponding log and error details.
4. Identify the root cause: input data, credentials, missing files, SQL, or database availability.
5. Fix the root cause; avoid changing expected test values just to pass.
6. Rerun the **complete** pipeline with `python src/06-run_pipeline.py`.
7. Verify seven successful steps, passing quality gates, and integration tests.
8. Retain prior failure records for audit history; do not relabel failures as successes.

**Consistency warning:** Silver and Gold commit separately. After a failed run, warehouse layers can represent different refresh attempts until a complete successful rerun. Avoid relying on partially refreshed data for reporting.

## 10. Safe failure simulation

The controller includes a test-only flag that fails before Bronze ingestion:

```bash
SIMULATE_PIPELINE_FAILURE=1 python src/06-run_pipeline.py
```

Expected: pipeline `FAILED`, first step `FAILED`, exit code `99`, and no Bronze ingestion attempted. Then verify normal execution:

```bash
python src/06-run_pipeline.py
```

Do not enable the simulation flag during normal operation.

## 11. Security and safety

- Never commit `.env`, credentials, or local log files.
- Review `.gitignore` before publishing.
- Do not run destructive tests against the working database.
- Do not run initialization scripts blindly against an existing database.
- Preserve operational audit history and investigate failures before rerunning.
- Back up important data before schema changes.

## 12. Current operational limitations

There is no automatic scheduler, retry policy, alerting, stale-run heartbeat, or atomic publication across all seven stages. See [Architecture](architecture.md) for design trade-offs.