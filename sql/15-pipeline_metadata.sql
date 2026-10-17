-- ============================================================
-- Stage 8: Pipeline operational metadata
-- ============================================================

CREATE SCHEMA IF NOT EXISTS etl;

CREATE TABLE IF NOT EXISTS etl.pipeline_runs (
    pipeline_id UUID PRIMARY KEY,

    status TEXT NOT NULL DEFAULT 'RUNNING'
        CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    error_message TEXT,

    CONSTRAINT chk_pipeline_completion
        CHECK (
            (status = 'RUNNING' AND completed_at IS NULL)
            OR
            (status IN ('SUCCESS', 'FAILED')
             AND completed_at IS NOT NULL)
        )
);

CREATE TABLE IF NOT EXISTS etl.pipeline_step_runs (
    step_run_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    pipeline_id UUID NOT NULL
        REFERENCES etl.pipeline_runs(pipeline_id),

    step_number INTEGER NOT NULL
        CHECK (step_number BETWEEN 1 AND 7),

    step_name TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'RUNNING'
        CHECK (status IN ('RUNNING', 'SUCCESS', 'FAILED')),

    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    duration_seconds NUMERIC(12,3)
        CHECK (duration_seconds >= 0),

    exit_code INTEGER,
    error_message TEXT,

    UNIQUE (pipeline_id, step_number),

    CONSTRAINT chk_step_completion
        CHECK (
            (status = 'RUNNING'
             AND completed_at IS NULL)
            OR
            (status IN ('SUCCESS', 'FAILED')
             AND completed_at IS NOT NULL)
        )
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_started
    ON etl.pipeline_runs(started_at DESC);

CREATE INDEX IF NOT EXISTS idx_pipeline_step_runs_pipeline
    ON etl.pipeline_step_runs(pipeline_id);