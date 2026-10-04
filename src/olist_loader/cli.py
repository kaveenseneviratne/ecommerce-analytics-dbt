"""Command-line entry point.

Examples:
    olist load --target duckdb --data-dir data/raw
    olist load --target bigquery --project my-gcp-project
    olist sample --out data/sample
"""

from __future__ import annotations

import argparse
import logging
import os
from collections.abc import Sequence
from pathlib import Path

from olist_loader import __version__
from olist_loader.load import LoadError, load_bigquery, load_duckdb
from olist_loader.sample_data import generate

logger = logging.getLogger("olist_loader")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="olist", description="Load Olist CSVs into a warehouse.")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    load = sub.add_parser("load", help="Load the raw CSVs into DuckDB or BigQuery.")
    load.add_argument("--target", choices=["duckdb", "bigquery"], default="duckdb")
    load.add_argument("--data-dir", type=Path, default=Path("data/raw"))
    load.add_argument("--schema", default="olist_raw", help="Schema / BigQuery dataset name.")
    load.add_argument("--duckdb-path", type=Path, default=Path("olist.duckdb"))
    load.add_argument("--project", default=os.environ.get("GCP_PROJECT"))
    load.add_argument("--location", default="EU")

    sample = sub.add_parser("sample", help="Write a synthetic dataset for local runs and CI.")
    sample.add_argument("--out", type=Path, default=Path("data/sample"))
    sample.add_argument("--orders", type=int, default=3_000)
    sample.add_argument("--seed", type=int, default=7)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(levelname)-7s %(message)s")

    if args.command == "sample":
        counts = generate(args.out, n_orders=args.orders, seed=args.seed)
        logger.info("Wrote %d files to %s (%s orders)", len(counts), args.out, f"{args.orders:,}")
        return 0

    try:
        if args.target == "duckdb":
            load_duckdb(args.data_dir, args.duckdb_path, args.schema)
        else:
            if not args.project:
                raise LoadError("Pass --project or set the GCP_PROJECT environment variable.")
            load_bigquery(args.data_dir, args.project, args.schema, args.location)
    except LoadError as exc:
        logger.error("%s", exc)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
