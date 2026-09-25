# E-commerce Analytics Data Platform

A local analytics engineering project that transforms deterministic synthetic e-commerce transactions into tested PostgreSQL dimensions, facts, and reporting marts with dbt.

Phase 1 demonstrates PostgreSQL, dbt modelling, source freshness, data quality, documentation, late-arriving updates, and idempotent incremental processing. All people, products, orders, and payments are synthetic.

## Business problem

Transactional tables are suitable for operating a shop but are awkward and risky for analytics. Payment retries can overstate collections, and multiple partial returns can multiply order-item rows if they are joined before aggregation. This project produces reliable answers to questions such as:

- How much gross and post-refund revenue did each channel produce per day?
- Which customers order most frequently and what is their current return behaviour?
- Did paid orders collect the correct pre-refund sales amount?
- Can late payments and returns update existing order facts without duplicates?

## Architecture

```text
Synthetic Python source generator
              |
              v
PostgreSQL raw (6 constrained source tables)
              |
              v
dbt staging views (one-to-one)
              |
              v
dbt intermediate views
              |
              v
core dimensions + facts
              |
              v
daily sales + customer 360 marts
```

The critical returns path aggregates events before joining them to order items:

```text
stg_returns -> int_returns_by_order_item -> int_order_item_financials
```

See [docs/architecture.md](docs/architecture.md) and [docs/metric_definitions.md](docs/metric_definitions.md) for design details and business definitions.

## Repository structure

```text
data_generator/       deterministic baseline and delta loader
dbt/models/staging/   one-to-one source models
dbt/models/intermediate/
                      payment, return, item, and order transformations
dbt/models/marts/core/
                      dimensions and facts
dbt/models/marts/reporting/
                      daily sales and customer 360
dbt/tests/            one generic and three singular business tests
docker/init/          raw PostgreSQL DDL
docs/                 architecture and metric definitions
```

## Prerequisites

- Python 3.11
- Docker with Docker Compose
- A shell capable of setting environment variables

## Local setup

```bash
cp .env.example .env
cp dbt/profiles.yml.example dbt/profiles.yml

python -m venv .venv
source .venv/bin/activate        # Windows PowerShell: .venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

docker compose up -d
docker compose ps
```

The example credentials are local development defaults only. Both `.env` and `dbt/profiles.yml` are ignored by Git.

## Baseline build

Run commands from the repository root:

```bash
python -m data_generator.generate_and_load --seed 42 --scale 1 --batch baseline

dbt debug --project-dir dbt --profiles-dir dbt
dbt source freshness --project-dir dbt --profiles-dir dbt
dbt build --project-dir dbt --profiles-dir dbt
```

The default scale creates a compact dataset suitable for local iteration. Increasing `--scale` multiplies its customer, product, and order counts while preserving deterministic behaviour for a seed.

## Baseline/delta demonstration

After the baseline build, load a deterministic delta and rebuild:

```bash
python -m data_generator.generate_and_load --seed 42 --scale 1 --batch delta
dbt build --project-dir dbt --profiles-dir dbt
```

The delta contains:

- New customers and orders
- A new order with a failed and then successful payment attempt
- A late successful payment that changes baseline order `2` from pending to paid
- Two partial return events against baseline order item `1`
- A late return that updates the corresponding existing order fact

Loading the same delta again uses stable primary keys and upserts, so it does not duplicate raw records.

Run the build once more without loading data to verify idempotency:

```bash
dbt build --project-dir dbt --profiles-dir dbt
```

## Incremental model

`fct_orders` is configured with:

- `unique_key = order_id`
- `incremental_strategy = delete+insert`
- `on_schema_change = fail`
- `source_updated_at` watermark
- Three-day lookback

The watermark includes upstream order, line, product, payment, and return updates. A late event therefore selects the affected order and replaces its existing fact row.

## Testing strategy

The project includes:

- Source freshness checks
- Unique and not-null primary-key tests
- Foreign-key relationship tests
- Accepted-value tests for controlled categories
- A reusable `non_negative` generic test
- Three business reconciliation tests
- Exactly two dbt unit tests covering payment retries and a partially returned discounted line

`dbt build` runs models, data tests, and unit tests in dependency order.

## dbt documentation and lineage

```bash
dbt docs generate --project-dir dbt --profiles-dir dbt
dbt docs serve --project-dir dbt --profiles-dir dbt
```

Open the displayed local URL to inspect source/model descriptions, column documentation, tests, and the complete lineage graph.

## Useful commands

```bash
docker compose down             # stop PostgreSQL, preserve data
docker compose down -v          # stop PostgreSQL and remove the development volume
dbt clean --project-dir dbt
```

## Current scope

This repository currently implements local PostgreSQL and dbt only. Terraform, AWS, point-in-time ML features, model training, APIs, Kubernetes, and cloud deployment are intentionally reserved for later phases.

