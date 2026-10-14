-- Stage 4: Data quality infrastructure

CREATE SCHEMA IF NOT EXISTS etl;

-- One record per execution of the quality framework
CREATE TABLE IF NOT EXISTS etl.data_quality_runs (
    run_id UUID PRIMARY KEY,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL
        CHECK (status IN ('RUNNING', 'PASS', 'FAIL', 'ERROR')),
    error_message TEXT
);

-- One record per quality check, per execution
CREATE TABLE IF NOT EXISTS etl.data_quality_results (
    result_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id UUID NOT NULL
        REFERENCES etl.data_quality_runs(run_id),
    check_name TEXT NOT NULL,
    dataset TEXT NOT NULL,
    failed_count BIGINT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('PASS', 'FAIL')),
    checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (run_id, check_name)
);

-- Invalid source records and their rejection reasons
CREATE TABLE IF NOT EXISTS etl.rejected_records (
    rejection_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id UUID NOT NULL
        REFERENCES etl.data_quality_runs(run_id),
    source_table TEXT NOT NULL,
    check_name TEXT NOT NULL,
    rejection_reason TEXT NOT NULL,
    record_data JSONB NOT NULL,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dq_results_run
    ON etl.data_quality_results(run_id);

CREATE INDEX IF NOT EXISTS idx_rejected_records_run
    ON etl.rejected_records(run_id);