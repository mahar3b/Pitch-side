"""
Pitch-side (PL Insights) DWBI Final Project
Script: 03_ETL/ingest.py
Description: Ingests raw CSVs untouched into PostgreSQL staging schema.
Deliverable: ETL Pipeline (15 marks) / Ingestion script
"""

import os
import glob
import pandas as pd
from sqlalchemy import create_engine, text

def load_dotenv():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    env_file = os.path.join(repo_root, ".env")
    if os.path.isfile(env_file):
        with open(env_file, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

def get_db_engine():
    load_dotenv()
    # Never hardcode credentials; read from environment
    user = os.environ.get("PGUSER", "postgres")
    pwd = os.environ.get("PGPASSWORD", "")
    host = os.environ.get("PGHOST", "localhost")
    port = os.environ.get("PGPORT", "5432")
    db = os.environ.get("PGDATABASE", "postgres")
    
    conn_url = f"postgresql+psycopg2://{user}:{pwd}@{host}:{port}/{db}"
    return create_engine(conn_url)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(script_dir, ".."))
    
    # Check possible raw data directory locations
    raw_candidates = [
        os.path.join(repo_root, "02_Data", "raw_data_16_seasons"),
        os.path.join(repo_root, "02_Data", "raw_data"),
        os.path.join(repo_root, "02_Data")
    ]
    raw_dir = None
    for candidate in raw_candidates:
        if os.path.isdir(candidate) and glob.glob(os.path.join(candidate, "E0_*.csv")):
            raw_dir = candidate
            break
            
    if not raw_dir:
        raise FileNotFoundError("Could not find raw CSV directory containing E0_*.csv files.")

    print(f"Reading raw CSVs from: {raw_dir}")
    seasons = [f"{y%100:02d}{(y+1)%100:02d}" for y in range(2010, 2026)] # 1011 ... 2526
    cols = ["Date", "HomeTeam", "AwayTeam", "FTHG", "FTAG", "FTR", "HTHG", "HTAG", "HTR", "Referee",
            "HS", "AS", "HST", "AST", "HF", "AF", "HC", "AC", "HY", "AY", "HR", "AR"]

    frames = []
    for s in seasons:
        fname = os.path.join(raw_dir, f"E0_{s}.csv")
        if not os.path.exists(fname):
            raise FileNotFoundError(f"Missing season file: {fname}")
        df = pd.read_csv(fname, encoding="latin-1", dtype=str).dropna(how="all")
        df = df.reindex(columns=cols)
        df["season"] = f"20{s[:2]}/{s[2:]}"
        df["source_file"] = os.path.basename(fname)
        frames.append(df)
        print(f"Season {s} ({df['season'].iloc[0]}): {len(df)} rows")

    stg = pd.concat(frames, ignore_index=True)
    print(f"Total raw match rows collected: {len(stg)} (expect 6,080)")

    eng = get_db_engine()
    with eng.begin() as con:
        con.execute(text("TRUNCATE project_staging.stg_matches;"))
        con.execute(text("TRUNCATE project_staging.stg_team_lookup;"))

    stg.to_sql("stg_matches", eng, schema="project_staging", if_exists="append",
               index=False, method="multi", chunksize=1000)
    print("Successfully ingested stg_matches.")

    # Team lookup (second source)
    lookup_candidates = [
        os.path.join(raw_dir, "team_lookup.csv"),
        os.path.join(repo_root, "02_Data", "team_lookup.csv")
    ]
    lk_path = next((p for p in lookup_candidates if os.path.exists(p)), None)
    if lk_path:
        df_lookup = pd.read_csv(lk_path, dtype=str)
        df_lookup.to_sql("stg_team_lookup", eng, schema="project_staging",
                         if_exists="append", index=False)
        print(f"Successfully ingested stg_team_lookup ({len(df_lookup)} teams).")
    else:
        print("WARNING: team_lookup.csv not found; stg_team_lookup is empty.")

if __name__ == "__main__":
    main()
