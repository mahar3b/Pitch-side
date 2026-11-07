# PL Insights: Project Progress & Implementation Log

## Current Status
- **Phase 1 (Design, 30 Marks):** COMPLETED & COMMITTED.
- **Phase 2 (Implementation, 40 Marks):** COMPLETED.
  - Staging schema and raw all-text tables created.
  - 16 seasons (6,080 fixtures) + secondary venue lookup ingested.
  - SQL data cleansing, type-casting, 41-club standardization, and 12,160-row unpivoting executed.
  - Star schema DDL with surrogate keys and unknown members (-1) deployed.
  - Dimension and fact load scripts deployed.
  - Automated 30-assertion DQ framework deployed (28 PASS, 2 INFO, 0 FAIL).
  - Data Cleaning Report (PDF) and Data Quality Report (PDF) generated.
- **Phase 3 (Analytics & BI, 30 Marks):** PENDING.

---

## Phase 2 Deliverables Checklist
- [x] Database SQL scripts (`03_ETL/00_create_schemas.sql`, `04_Data_Warehouse/warehouse.sql`)
- [x] Staging schema SQL (`03_ETL/staging.sql`)
- [x] DW schema SQL (`04_Data_Warehouse/warehouse.sql`)
- [x] ETL scripts (`03_ETL/ingest.py`, `03_ETL/run_all.py`)
- [x] Dimension load scripts (`03_ETL/dimensions.sql`)
- [x] Fact load scripts (`03_ETL/facts.sql`)
- [x] Data Quality verification script (`03_ETL/data_quality.sql`)
- [x] Data Cleaning Report PDF (`project_documentation/Phase2_Reports/Data_Cleaning_Report.pdf`)
- [x] Data Quality Report PDF (`project_documentation/Phase2_Reports/Data_Quality_Report.pdf`)
- [x] Master one-command rebuild script (`03_ETL/run_all.py`)
- [x] README documentation updated with execution instructions & DQ matrix
- [ ] Git commit and push

---

## Database Object Row Counts
| Schema | Table | Type | Count |
|---|---|---|---|
| `project_staging` | `stg_matches` | Staging Raw | 6,080 |
| `project_staging` | `stg_team_lookup` | Staging Secondary | 41 |
| `project_staging` | `stg_matches_clean` | Staging Clean | 6,080 |
| `project_staging` | `stg_match_team` | Staging Unpivoted | 12,160 |
| `project_dw` | `dim_date` | Dimension | 5,845 |
| `project_dw` | `dim_season` | Dimension | 17 |
| `project_dw` | `dim_team` | Dimension | 42 |
| `project_dw` | `dim_referee` | Dimension | 55 |
| `project_dw` | `dim_venue` | Dimension | 42 |
| `project_dw` | `fact_match_team` | Transaction Fact | 12,160 |
| `project_dw` | `fact_team_matchweek_snapshot` | Periodic Snapshot | 12,160 |
| `project_dw` | `fact_team_season` | Factless Fact | 320 |
| `project_dw` | `dq_results` | Audit Framework | 30 checks (All Pass) |
