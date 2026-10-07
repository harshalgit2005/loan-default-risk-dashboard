"""
Build the SQLite database, run the SQL scripts in order, and export the
CSV files that Power BI will import. Run:  python scripts/02_build_db_and_export.py
"""
import sqlite3
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
DB = ROOT / "output" / "loan_risk.db"
OUT = ROOT / "output"

def run_script(con, name):
    sql = (ROOT / "sql" / name).read_text()
    con.executescript(sql)

DB.unlink(missing_ok=True)
con = sqlite3.connect(DB)

run_script(con, "01_schema.sql")
pd.read_csv(ROOT / "data" / "customers.csv").to_sql("customers", con, if_exists="append", index=False)
pd.read_csv(ROOT / "data" / "loans.csv").to_sql("loans", con, if_exists="append", index=False)

for f in ["02_data_quality_and_features.sql", "03_segment_analysis.sql", "04_review_queue.sql"]:
    run_script(con, f)

exports = {
    "fact_loans.csv":          "SELECT * FROM vw_loan_base",
    "segment_default_rates.csv": "SELECT * FROM vw_segment_default_rates",
    "review_queue.csv":        "SELECT * FROM vw_review_queue",
}
for fname, q in exports.items():
    df = pd.read_sql(q, con)
    df.to_csv(OUT / fname, index=False)
    print(f"exported {fname}: {len(df):,} rows")

print("\n--- Quick findings ---")
print(pd.read_sql("SELECT dimension, segment, loans, default_rate_pct, risk_lift FROM vw_segment_default_rates WHERE loans>=200 ORDER BY default_rate_pct DESC LIMIT 8", con).to_string(index=False))
print()
print(pd.read_sql("SELECT recommended_route, COUNT(*) n FROM vw_review_queue GROUP BY 1", con).to_string(index=False))
con.close()
