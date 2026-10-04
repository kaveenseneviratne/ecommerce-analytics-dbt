"""Land the raw CSVs in a warehouse, unchanged.

Every column is loaded as a string. Typing, renaming and cleaning happen in dbt staging
models, where they're version-controlled and tested. This keeps the load step dumb and
repeatable: if a cast is wrong, we fix SQL and rebuild, we don't reload files.
"""

from __future__ import annotations

import csv
import logging
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

from olist_loader.tables import EXPECTED_COLUMNS, RAW_TABLES

logger = logging.getLogger(__name__)


class LoadError(RuntimeError):
    """Raised when input files are missing or don't match the expected layout."""


@dataclass(frozen=True)
class LoadResult:
    table: str
    rows: int


def read_header(path: Path) -> list[str]:
    # utf-8-sig strips the byte-order mark that one of the Kaggle files ships with
    with path.open(encoding="utf-8-sig", newline="") as fh:
        return next(csv.reader(fh))


def resolve_files(data_dir: Path) -> dict[str, Path]:
    """Map each raw table to its CSV, checking every file exists and has the right header."""
    files = {table: data_dir / filename for table, filename in RAW_TABLES.items()}

    missing = sorted(p.name for p in files.values() if not p.is_file())
    if missing:
        raise LoadError(
            f"{len(missing)} file(s) missing from {data_dir}: {', '.join(missing)}. "
            "Download and unzip the Olist dataset from Kaggle into that folder."
        )

    for table, path in files.items():
        header = tuple(read_header(path))
        if header != EXPECTED_COLUMNS[table]:
            raise LoadError(
                f"{path.name} has unexpected columns.\n"
                f"  expected: {list(EXPECTED_COLUMNS[table])}\n  found:    {list(header)}"
            )
    return files


def load_duckdb(data_dir: Path, db_path: Path, schema: str) -> list[LoadResult]:
    import duckdb

    files = resolve_files(data_dir)
    results = []
    with duckdb.connect(str(db_path)) as con:
        con.execute(f'create schema if not exists "{schema}"')
        for table, path in files.items():
            con.execute(
                f'create or replace table "{schema}"."{table}" as '
                "select * from read_csv(?, header = true, all_varchar = true, quote = '\"')",
                [str(path)],
            )
            count = con.execute(f'select count(*) from "{schema}"."{table}"').fetchone()
            results.append(LoadResult(table, int(count[0]) if count else 0))
            logger.info("Loaded %-50s %10s rows", f"{schema}.{table}", f"{results[-1].rows:,}")
    return results


def load_bigquery(data_dir: Path, project: str, dataset: str, location: str) -> list[LoadResult]:
    from google.cloud import bigquery

    files = resolve_files(data_dir)
    client = bigquery.Client(project=project, location=location)

    ds = bigquery.Dataset(f"{project}.{dataset}")
    ds.location = location
    client.create_dataset(ds, exists_ok=True)

    results = []
    for table, path in files.items():
        job_config = bigquery.LoadJobConfig(
            source_format=bigquery.SourceFormat.CSV,
            skip_leading_rows=1,
            schema=[bigquery.SchemaField(col, "STRING") for col in EXPECTED_COLUMNS[table]],
            write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
            # review comments contain line breaks inside quoted fields
            allow_quoted_newlines=True,
        )
        table_id = f"{project}.{dataset}.{table}"
        with path.open("rb") as fh:
            job = client.load_table_from_file(fh, table_id, job_config=job_config)
        job.result()  # blocks, and raises with BigQuery's error message if the load fails

        rows = client.get_table(table_id).num_rows or 0
        results.append(LoadResult(table, rows))
        logger.info("Loaded %-50s %10s rows", f"{dataset}.{table}", f"{rows:,}")
    return results


def summarise(results: list[LoadResult]) -> Mapping[str, int]:
    return {r.table: r.rows for r in results}
