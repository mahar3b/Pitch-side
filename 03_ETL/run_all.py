"""
Pitch-side (PL Insights) DWBI Final Project
Script: 03_ETL/run_all.py
Description: End-to-end idempotent pipeline executor (covers 'instructors test from scratch')
Deliverable: ETL Pipeline (15 marks) & Re-runnable master script
"""

import os
import sys
import subprocess
import psycopg2

def load_dotenv():
    # Attempt to load from .env file if it exists
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    env_file = os.path.join(repo_root, ".env")
    if os.path.isfile(env_file):
        with open(env_file, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

def get_connection():
    user = os.environ.get("PGUSER", "postgres")
    pwd = os.environ.get("PGPASSWORD", "")
    host = os.environ.get("PGHOST", "localhost")
    port = os.environ.get("PGPORT", "5432")
    db = os.environ.get("PGDATABASE", "pitch_side")
    return psycopg2.connect(dbname=db, user=user, password=pwd, host=host, port=port)

def run_sql_file(file_path):
    print(f"\n[SQL] Executing {os.path.basename(file_path)}...")
    conn = get_connection()
    conn.autocommit = True
    with conn.cursor() as cur:
        with open(file_path, "r", encoding="utf-8") as f:
            sql = f.read()
            cur.execute(sql)
            if cur.description:
                rows = cur.fetchall()
                cols = [desc[0] for desc in cur.description]
                print(f"Result ({len(rows)} rows):")
                print(" | ".join(cols))
                print("-" * 60)
                for r in rows[:10]:
                    print(" | ".join(str(val) for val in r))
                if len(rows) > 10:
                    print(f"... ({len(rows) - 10} more rows)")
    conn.close()
    print(f"[SQL] Finished {os.path.basename(file_path)} successfully.")

def run_python_file(file_path):
    print(f"\n[PY] Executing {os.path.basename(file_path)}...")
    res = subprocess.run([sys.executable, file_path], check=True)
    print(f"[PY] Finished {os.path.basename(file_path)} successfully.")

def main():
    load_dotenv()
    here = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(here, ".."))

    steps = [
        ("sql", os.path.join(here, "00_create_schemas.sql")),
        ("py",  os.path.join(here, "ingest.py")),
        ("sql", os.path.join(here, "staging.sql")),
        ("sql", os.path.join(repo_root, "04_Data_Warehouse", "warehouse.sql")),
        ("sql", os.path.join(here, "dimensions.sql")),
        ("sql", os.path.join(here, "facts.sql")),
        ("sql", os.path.join(here, "data_quality.sql")),
    ]

    print("============================================================")
    print("PL INSIGHTS - END-TO-END DATA WAREHOUSE ETL PIPELINE")
    print("============================================================")

    for kind, path in steps:
        if kind == "sql":
            run_sql_file(path)
        elif kind == "py":
            run_python_file(path)

    print("\n============================================================")
    print("ETL PIPELINE COMPLETE - ALL STEPS EXECUTED SUCCESSFULLY")
    print("============================================================")

if __name__ == "__main__":
    main()
