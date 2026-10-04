.PHONY: help install sample load load-bq build build-bq lint test check docs clean

help:  ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-10s %s\n", $$1, $$2}'

install:  ## Install Python deps, dbt packages and git hooks
	python -m pip install -e ".[dev]"
	dbt deps
	pre-commit install

sample:  ## Generate synthetic data and load it into local DuckDB
	olist sample --out data/sample
	olist load --target duckdb --data-dir data/sample

load:  ## Load the real Kaggle CSVs from data/raw into local DuckDB
	olist load --target duckdb --data-dir data/raw

load-bq:  ## Load the real Kaggle CSVs into BigQuery (needs GCP_PROJECT)
	olist load --target bigquery --data-dir data/raw

build:  ## Build and test every model in local DuckDB
	dbt build

build-bq:  ## Build and test every model in BigQuery
	dbt build --target dev

lint:  ## Lint SQL and Python
	sqlfluff lint models analyses tests/dbt
	ruff check src tests/python
	ruff format --check src tests/python

test:  ## Python unit tests
	pytest

check: sample build lint test  ## Everything CI runs

docs:  ## Generate and open the dbt docs site
	dbt docs generate
	dbt docs serve

clean:  ## Remove build artefacts and local databases
	dbt clean
	rm -rf logs .pytest_cache .ruff_cache *.duckdb *.duckdb.wal data/sample
