# PL Insights: English Premier League Data Warehouse & BI Platform

**Course:** DL3004 Data Warehousing & Business Intelligence  
**Institution:** FAST-NUCES Lahore (BDS Program)  
**Author:** Mahareb (24L-2540)  
**Scope:** 16 Premier League Seasons (2010/11 – 2025/26) | 6,080 Matches | 12,160 Fact Records

---

## 1. Project Overview

**PL Insights** is an end-to-end Data Warehouse and Business Intelligence solution engineered to analyze 16 seasons of English Premier League match statistics. The system investigates club performance trajectories, home field advantage dynamics, scoring trends, and match official disciplinary tendencies.

- **Source Data:** 16 annual match datasets from `football-data.co.uk` (6,080 fixtures) plus a secondary stadium and venue capacity lookup (`team_lookup.csv`).
- **Target Schema:** Star schema implemented on PostgreSQL partitioned into `project_staging`, `project_dw`, and `project_reporting`.
- **Target Scale:** 12,160 transaction fact records (2 records per match at the team-match grain), 5,845 calendar dimension records, and 42 standardized club profiles.

---

## 2. Dimensional Architecture (Star Schema)

The analytical data warehouse adheres to dimensional modeling best practices, centering around a high-grain transaction fact table supported by periodic snapshot and factless facts:

```
                         +-------------------+
                         |     dim_date      |
                         +-------------------+
                                   |
+--------------------+   +-------------------+   +--------------------+
|     dim_season     |---|  fact_match_team  |---|     dim_referee    |
+--------------------+   +-------------------+   +--------------------+
       |       |           |               |               |
       |       |     +----------+     +----------+         |
       |       +-----| dim_team |-----| dim_venue|         |
       |             +----------+     +----------+         |
       |                   |                               |
       |        (Role: Opponent Team)                      |
       |                   |                               |
+------------------------------------+                     |
|    fact_team_matchweek_snapshot    |                     |
+------------------------------------+                     |
|          fact_team_season          |---------------------+
+------------------------------------+
```

### Table Specifications

| Table | Type | Grain | Key Attributes / Measures | Row Count |
|---|---|---|---|---|
| `fact_match_team` | Transaction Fact | 1 row per team per match | `fact_match_team_sk`, `match_id`, `goals_for`, `goals_against`, `points`, `is_win`, `is_draw`, `is_loss`, `shots`, `shots_on_target`, `corners`, `fouls_committed`, `yellow_cards`, `red_cards` | **12,160** |
| `fact_team_matchweek_snapshot` | Periodic Snapshot | 1 row per team after matchweek N | `snapshot_sk`, `matchweek`, `cum_points`, `cum_goals_for`, `cum_goals_against`, `cum_goal_difference`, `league_position`, `points_last5` | **12,160** |
| `fact_team_season` | Factless Fact | 1 row per participating team per season | `team_season_sk`, `season_sk`, `team_sk` | **320** |
| `dim_date` | Dimension | 1 row per calendar day | `date_sk` (YYYYMMDD), `full_date`, `day_of_week`, `day_name`, `month`, `month_name`, `quarter`, `year`, `is_weekend` | **5,845** |
| `dim_season` | Dimension | 1 row per season | `season_sk`, `season_code` (e.g. 2023/24), `season_years`, `start_year`, `end_year` | **17** |
| `dim_team` | Dimension | 1 row per club | `team_sk`, `team_name` (canonical), `city`, `stadium`, `capacity`, `is_active` | **42** |
| `dim_referee` | Dimension | 1 row per official | `referee_sk`, `referee_name` | **55** |
| `dim_venue` | Dimension | 1 row per venue | `venue_sk`, `stadium_name`, `city`, `capacity` | **42** |

*(Note: Dimensions include an unknown member with surrogate key `-1` to safeguard referential integrity against missing data).*

---

## 3. Repository Structure

```
Pitch-side/
├── 01_Project_Documentation/
│   ├── Phase1/                               # Proposal, Requirements, Grain, Fact/Dim docs
│   ├── Phase2_Reports/
│   │   ├── Data_Cleaning_Report.pdf          # Full cleansing audit & before/after transformations
│   │   └── Data_Quality_Report.pdf           # 30-assertion DQ test matrix & findings
│   ├── pitch side_Data Dictionary.xlsx
│   ├── pitch_side_star_schema.md
│   └── star_schema_diagram.png
├── 02_Data/
│   └── raw_data_16_seasons/
│       ├── E0_1011.csv ... E0_2526.csv       # 16 seasons raw match data (380 matches each)
│       └── team_lookup.csv                   # Secondary lookup: stadium, city, capacity
├── 03_ETL/
│   ├── 00_create_schemas.sql                 # DDL for project_staging, project_dw, project_reporting
│   ├── ingest.py                             # Untouched CSV ingestion into project_staging
│   ├── staging.sql                           # Cleansing, type-casting, team mapping, unpivoting
│   ├── dimensions.sql                        # Dimension population with surrogate keys & unknown members
│   ├── facts.sql                             # Business-to-surrogate key joins for facts
│   ├── data_quality.sql                      # Automated 30-test DQ assertion suite
│   └── run_all.py                            # Idempotent master pipeline runner
├── 04_Data_Warehouse/
│   └── warehouse.sql                         # Complete DDL for project_dw star schema
├── 05_Analytics/                             # Phase 3 analytical SQL & OLAP scripts (upcoming)
├── .gitignore                                # Ignores .env and temporary files
└── README.md
```

---

## 4. Setup and Execution Guide

### Prerequisites
- **PostgreSQL 14+** running locally on port 5432.
- **Python 3.10+** with required packages:
  ```bash
  pip install pandas sqlalchemy psycopg2-binary reportlab tabulate openpyxl
  ```

### Configuration
Create a `.env` file in the repository root (ignored by Git):
```ini
PGUSER=postgres
PGPASSWORD=your_password
PGHOST=localhost
PGPORT=5432
PGDATABASE=postgres
```

### Running the Complete Pipeline
To rebuild the entire staging, warehouse, and data quality suite idempotently in a single command:
```bash
python 03_ETL/run_all.py
```

Or execute sequentially via `psql` / pgAdmin:
1. `03_ETL/00_create_schemas.sql`
2. `python 03_ETL/ingest.py`
3. `03_ETL/staging.sql`
4. `04_Data_Warehouse/warehouse.sql`
5. `03_ETL/dimensions.sql`
6. `03_ETL/facts.sql`
7. `03_ETL/data_quality.sql`

---

## 5. Data Quality Validation Matrix

The automated validation suite (`project_dw.dq_results`) executes **30 assertions** after every pipeline run:

| Category | Assertions Evaluated | Expected | Actual | Status |
|---|---|---|---|---|
| **Completeness** | Zero NULL values across all PKs, FKs, and measures | 0 NULLs | 0 NULLs | **PASS (11/11)** |
| **Completeness** | Unknown member fallback tracking (referee & venue) | Informational | 0 | **INFO (2/2)** |
| **Accuracy** | Reconciliation: `SUM(goals_for)` DW vs `SUM(FTHG+FTAG)` Staging | 17,018 | 17,018 | **PASS** |
| **Accuracy** | Fact row count = 2 x Clean match count | 12,160 | 12,160 | **PASS** |
| **Accuracy** | Matches per season = 380 across all 16 seasons | 0 deviations | 0 deviations | **PASS** |
| **Accuracy** | Matches per team-season = 38 across all 320 instances | 0 deviations | 0 deviations | **PASS** |
| **Accuracy** | Match points validation: sums to 3 (win/loss) or 2 (draw) | 0 invalid | 0 invalid | **PASS** |
| **Integrity** | Fact table foreign key orphan checks against all dimensions | 0 orphans | 0 orphans | **PASS (8/8)** |
| **Integrity** | Grain uniqueness constraint `(match_id, team_sk)` | 0 duplicates | 0 duplicates | **PASS** |
| **Volume** | `fact_match_team` rows $\ge$ 10,000 (Course Rubric) | $\ge$ 10,000 | **12,160** | **PASS** |
| **Volume** | `dim_date` calendar rows $\ge$ 100 (Course Rubric) | $\ge$ 100 | **5,845** | **PASS** |
| **Volume** | `dim_team` records $\ge$ 40 | $\ge$ 40 | **42** | **PASS** |

**Overall Score:** 28 Passed | 2 Informational | 0 Failed.
