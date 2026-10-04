from __future__ import annotations

from pathlib import Path

import duckdb
import pytest

from olist_loader.cli import main
from olist_loader.load import LoadError, load_duckdb, read_header, resolve_files
from olist_loader.sample_data import generate
from olist_loader.tables import EXPECTED_COLUMNS, RAW_TABLES


@pytest.fixture(scope="module")
def sample_dir(tmp_path_factory: pytest.TempPathFactory) -> Path:
    out = tmp_path_factory.mktemp("sample")
    generate(out, n_orders=400, seed=1)
    return out


def test_generator_writes_every_file_with_published_headers(sample_dir: Path) -> None:
    for table, filename in RAW_TABLES.items():
        assert read_header(sample_dir / filename) == list(EXPECTED_COLUMNS[table])


def test_generator_is_deterministic(tmp_path: Path) -> None:
    generate(tmp_path / "a", n_orders=100, seed=3)
    generate(tmp_path / "b", n_orders=100, seed=3)
    for filename in RAW_TABLES.values():
        assert (tmp_path / "a" / filename).read_bytes() == (tmp_path / "b" / filename).read_bytes()


def test_bom_is_stripped_from_header(sample_dir: Path) -> None:
    # the translation file is written with a byte-order mark, like the real one
    path = sample_dir / RAW_TABLES["product_category_name_translation"]
    assert path.read_bytes().startswith(b"\xef\xbb\xbf")
    assert read_header(path)[0] == "product_category_name"


def test_missing_files_are_listed(tmp_path: Path) -> None:
    with pytest.raises(LoadError, match="9 file"):
        resolve_files(tmp_path)


def test_unexpected_columns_are_rejected(sample_dir: Path, tmp_path: Path) -> None:
    for filename in RAW_TABLES.values():
        (tmp_path / filename).write_bytes((sample_dir / filename).read_bytes())
    orders = tmp_path / RAW_TABLES["orders"]
    lines = orders.read_text().splitlines()
    lines[0] = lines[0].replace("order_status", "status")
    orders.write_text("\n".join(lines) + "\n")

    with pytest.raises(LoadError, match="unexpected columns"):
        resolve_files(tmp_path)


def test_duckdb_load_keeps_every_row_as_text(sample_dir: Path, tmp_path: Path) -> None:
    db = tmp_path / "test.duckdb"
    results = {r.table: r.rows for r in load_duckdb(sample_dir, db, "olist_raw")}

    with duckdb.connect(str(db), read_only=True) as con:
        types = con.execute(
            "select distinct data_type from information_schema.columns "
            "where table_schema = 'olist_raw'"
        ).fetchall()
        # comments with line breaks must survive as a single row each
        multiline = con.execute(
            "select count(*) from olist_raw.order_reviews "
            "where review_comment_message like '%' || chr(10) || '%'"
        ).fetchone()

    assert set(results) == set(RAW_TABLES)
    assert all(rows > 0 for rows in results.values())
    assert types == [("VARCHAR",)]
    assert multiline is not None and multiline[0] > 0


def test_cli_sample_then_load(tmp_path: Path) -> None:
    out, db = tmp_path / "data", tmp_path / "cli.duckdb"
    assert main(["sample", "--out", str(out), "--orders", "50"]) == 0
    assert main(["load", "--data-dir", str(out), "--duckdb-path", str(db)]) == 0


def test_cli_reports_missing_data(tmp_path: Path) -> None:
    assert main(["load", "--data-dir", str(tmp_path), "--duckdb-path", str(tmp_path / "x")]) == 1


def test_bigquery_target_requires_project(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("GCP_PROJECT", raising=False)
    assert main(["load", "--target", "bigquery", "--data-dir", str(tmp_path)]) == 1
