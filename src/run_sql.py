"""Execute every query in sql/ with DuckDB and write results to outputs/*.csv."""
from pathlib import Path
import duckdb

ROOT = Path(__file__).resolve().parents[1]
RAW = (ROOT / "data" / "raw").as_posix() + "/"
SQL = ROOT / "sql"
OUT = ROOT / "outputs"


def connect() -> duckdb.DuckDBPyConnection:
    con = duckdb.connect()
    con.execute((SQL / "00_views.sql").read_text().replace("{RAW}", RAW))
    return con


def main() -> None:
    OUT.mkdir(exist_ok=True)
    con = connect()
    for f in sorted(SQL.glob("*.sql")):
        if f.name.startswith("00_"):
            continue
        df = con.execute(f.read_text()).df()
        df.to_csv(OUT / f"{f.stem}.csv", index=False)
        print(f"{f.name:40s} -> {len(df):6d} rows")


if __name__ == "__main__":
    main()
