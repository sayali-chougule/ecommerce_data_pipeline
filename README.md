
# Olist E-commerce ELT Pipeline

An end-to-end data engineering project that transforms the
Olist Brazilian E-Commerce dataset from raw CSV files into
analytics-ready PostgreSQL tables and views.

The project demonstrates Python-based ingestion, SQL
transformations, dimensional modeling, automated data quality,
pipeline orchestration, testing, and operational observability.

## Tech Stack

- Python 3.9
- PostgreSQL
- psycopg 3
- SQL
- pytest
- VS Code
- Git

## Architecture

![alt text](docs/01-pipeline_architecture.png)

Pipeline execution history, step status, ingestion batches,
and quality results are recorded in the `etl` schema.

## Data Source

Olist Brazilian E-Commerce Public Dataset:

https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

The dataset contains nine source CSV files describing
customers, orders, items, products, sellers, payments,
reviews, geolocation, and category translations.

## Data Layers

### Bronze

Nine raw tables preserve source values primarily as text,
with ingestion metadata such as batch ID, source filename,
and ingestion timestamp.

### Silver

Nine typed tables apply data type conversion, primary keys,
foreign keys, and validation constraints.

### Gold

Three dimensions:

- `gold.dim_customers`
- `gold.dim_products`
- `gold.dim_sellers`

One fact table:

- `gold.fact_order_items`

Five analytical views:

- `gold.vw_order_metrics`
- `gold.vw_monthly_sales`
- `gold.vw_category_performance`
- `gold.vw_state_performance`
- `gold.vw_customer_purchase_summary`

The fact table grain is one order item, identified by
`(order_id, order_item_id)`.

## Pipeline Steps

1. Bronze ingestion
2. Pre-transformation quality validation
3. Silver transformation
4. Post-transformation reconciliation
5. Gold transformation
6. Gold analytical view creation
7. Gold validation

The pipeline stops when a required step fails.

## Local Setup

### Prerequisites

- Python 3.9-compatible environment
- PostgreSQL installed and running
- PostgreSQL `psql` command available
- Olist CSV files downloaded separately

### 1. Create a virtual environment

```bash
python3 -m venv .project1
source .project1/bin/activate
```

### 2. Install dependencies

```bash
python -m pip install -r requirements.txt
```

### 3. Configure the database

Create a local PostgreSQL database named `ecommerce_dw`.

Copy the environment template:

```bash
cp .env.example .env
```

Edit `.env` with your local PostgreSQL credentials.

Never commit `.env`.

### 4. Place the source data

Place the nine Olist CSV files into:

```text
data/raw/
```

Extract the nine Olist CSV files into:

```text
data/extracted/
```

### 5. Initialize the database

Run the schema setup scripts in dependency order.

Refer to [Runbook](docs/runbook.md) for the exact
initialization commands.

### 6. Execute the pipeline

```bash
python src/05-run_pipeline.py
```

### 7. Run automated tests

Unit tests:

```bash
python -m pytest -v
```

Read-only PostgreSQL integration tests:

```bash
RUN_DB_TESTS=1 python -m pytest -v
```

## Data Quality

The project includes checks for:

- Missing customer identifiers
- Duplicate order identifiers
- Invalid order-item prices
- Invalid review scores
- Orphaned order items
- Bronze/Silver count reconciliation
- Gold fact count and grain
- Gold dimension coverage
- Gold analytical metric reconciliation

Quality results are stored in the `etl` schema.

## Observability

Operational metadata includes:

- `etl.ingestion_batches`
- `etl.data_quality_runs`
- `etl.data_quality_results`
- `etl.rejected_records`
- `etl.pipeline_runs`
- `etl.pipeline_step_runs`

The pipeline records status, timestamps, step duration,
exit codes, and error messages.

## Analytical Use Cases

The Gold views support:

- Monthly delivered merchandise value
- Average order value
- Category performance
- Customer-state performance
- Repeat customer analysis

Merchandise value is based on order-item prices.
It is not equivalent to recognized accounting revenue.

## Design Decisions

- Full-refresh processing for a static dataset
- ELT transformations performed in PostgreSQL
- Bronze/Silver/Gold layered architecture
- Dimensional Gold model with order-item grain
- Fail-fast orchestration
- Database-backed operational metadata

## Known Limitations

- No incremental ingestion or CDC
- No scheduling service
- No automatic retry policy
- No centralized monitoring or alerting
- No end-to-end transaction across all pipeline stages
- No Slowly Changing Dimension Type 2 history
- Local deployment only

## Additional Documentation

- [Architecture and design decisions](docs/architecture.md)
- [Operational runbook](docs/runbook.md)
- [Portfolio walkthrough](docs/portfolio.md)