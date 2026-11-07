-- ============================================================================
-- Pitch-side (PL Insights) DWBI Final Project
-- Script: 03_ETL/data_quality.sql
-- Description: Automated Data Quality validation framework
-- Deliverable: Data Quality Validation (10 marks) & DQ Report Source
-- ============================================================================

SET search_path = project_dw;

DROP TABLE IF EXISTS project_dw.dq_results CASCADE;
CREATE TABLE project_dw.dq_results (
  check_id serial PRIMARY KEY,
  category text NOT NULL,
  check_name text NOT NULL,
  expected text NOT NULL,
  actual text NOT NULL,
  status text NOT NULL,
  run_at timestamp DEFAULT clock_timestamp()
);

-- ----------------------------------------------------------------------------
-- 1. COMPLETENESS: NULLs in critical PK/FK and measure columns must be 0
-- ----------------------------------------------------------------------------
INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Completeness' AS category, 
  c.name AS check_name, 
  '0' AS expected, 
  c.n::text AS actual, 
  CASE WHEN c.n = 0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
  SELECT 'fact_match_team NULL date_sk' AS name, COUNT(*) AS n FROM fact_match_team WHERE date_sk IS NULL
  UNION ALL SELECT 'fact_match_team NULL season_sk', COUNT(*) FROM fact_match_team WHERE season_sk IS NULL
  UNION ALL SELECT 'fact_match_team NULL team_sk', COUNT(*) FROM fact_match_team WHERE team_sk IS NULL
  UNION ALL SELECT 'fact_match_team NULL opponent_team_sk', COUNT(*) FROM fact_match_team WHERE opponent_team_sk IS NULL
  UNION ALL SELECT 'fact_match_team NULL referee_sk', COUNT(*) FROM fact_match_team WHERE referee_sk IS NULL
  UNION ALL SELECT 'fact_match_team NULL venue_sk', COUNT(*) FROM fact_match_team WHERE venue_sk IS NULL
  UNION ALL SELECT 'fact_match_team NULL goals_for/against', COUNT(*) FROM fact_match_team WHERE goals_for IS NULL OR goals_against IS NULL
  UNION ALL SELECT 'dim_team NULL team_name', COUNT(*) FROM dim_team WHERE team_name IS NULL
  UNION ALL SELECT 'dim_referee NULL referee_name', COUNT(*) FROM dim_referee WHERE referee_name IS NULL
  UNION ALL SELECT 'dim_season NULL season_code', COUNT(*) FROM dim_season WHERE season_code IS NULL
  UNION ALL SELECT 'dim_date NULL full_date (excl. unknown)', COUNT(*) FROM dim_date WHERE full_date IS NULL AND date_sk <> -1
) c;

-- Informational tracking of records mapping to unknown surrogate keys (-1)
INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'fact rows with unknown referee (-1) [info]', 'n/a',
       COUNT(*)::text, 'INFO' FROM fact_match_team WHERE referee_sk = -1;

INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 'Completeness', 'fact rows with unknown venue (-1) [info]', 'n/a',
       COUNT(*)::text, 'INFO' FROM fact_match_team WHERE venue_sk = -1;

-- ----------------------------------------------------------------------------
-- 2. ACCURACY: Reconciliation between staging and warehouse layers
-- ----------------------------------------------------------------------------
INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Accuracy', 
  'SUM(goals_for) in DW = SUM(FTHG + FTAG) in staging',
  (SELECT SUM(fthg + ftag)::text FROM project_staging.stg_matches_clean),
  (SELECT SUM(goals_for)::text FROM fact_match_team),
  CASE 
    WHEN (SELECT SUM(fthg + ftag) FROM project_staging.stg_matches_clean) = (SELECT SUM(goals_for) FROM fact_match_team) 
    THEN 'PASS' 
    ELSE 'FAIL' 
  END;

INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Accuracy', 
  'fact_match_team count = 2 x clean matches (12,160)',
  (SELECT (2 * COUNT(*))::text FROM project_staging.stg_matches_clean),
  (SELECT COUNT(*)::text FROM fact_match_team),
  CASE 
    WHEN (SELECT 2 * COUNT(*) FROM project_staging.stg_matches_clean) = (SELECT COUNT(*) FROM fact_match_team) 
    THEN 'PASS' 
    ELSE 'FAIL' 
  END;

INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Accuracy', 
  'seasons with != 380 matches', 
  '0', 
  COUNT(*)::text,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
  SELECT season FROM project_staging.stg_matches_clean GROUP BY season HAVING COUNT(*) <> 380
) x;

INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Accuracy', 
  'team-seasons with != 38 matches', 
  '0', 
  COUNT(*)::text,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
  SELECT season_sk, team_sk FROM fact_match_team GROUP BY 1, 2 HAVING COUNT(*) <> 38
) x;

INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Accuracy', 
  'matches with points not summing to 3 (win/loss) or 2 (draw)', 
  '0', 
  COUNT(*)::text,
  CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
  SELECT match_id FROM fact_match_team GROUP BY match_id HAVING SUM(points) NOT IN (2, 3)
) x;

-- ----------------------------------------------------------------------------
-- 3. INTEGRITY: Zero orphan fact records and zero duplicate grain keys
-- ----------------------------------------------------------------------------
INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Integrity', 
  c.name, 
  '0', 
  c.n::text, 
  CASE WHEN c.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
  SELECT 'fact rows without dim_date' AS name, COUNT(*) AS n 
    FROM fact_match_team f LEFT JOIN dim_date d ON d.date_sk = f.date_sk WHERE d.date_sk IS NULL
  UNION ALL 
  SELECT 'fact rows without dim_season', COUNT(*) 
    FROM fact_match_team f LEFT JOIN dim_season s ON s.season_sk = f.season_sk WHERE s.season_sk IS NULL
  UNION ALL 
  SELECT 'fact rows without dim_team', COUNT(*) 
    FROM fact_match_team f LEFT JOIN dim_team t ON t.team_sk = f.team_sk WHERE t.team_sk IS NULL
  UNION ALL 
  SELECT 'fact rows without opponent dim_team', COUNT(*) 
    FROM fact_match_team f LEFT JOIN dim_team t ON t.team_sk = f.opponent_team_sk WHERE t.team_sk IS NULL
  UNION ALL 
  SELECT 'fact rows without dim_referee', COUNT(*) 
    FROM fact_match_team f LEFT JOIN dim_referee r ON r.referee_sk = f.referee_sk WHERE r.referee_sk IS NULL
  UNION ALL 
  SELECT 'fact rows without dim_venue', COUNT(*) 
    FROM fact_match_team f LEFT JOIN dim_venue v ON v.venue_sk = f.venue_sk WHERE v.venue_sk IS NULL
  UNION ALL 
  SELECT 'snapshot rows without dim_team', COUNT(*) 
    FROM fact_team_matchweek_snapshot x LEFT JOIN dim_team t ON t.team_sk = x.team_sk WHERE t.team_sk IS NULL
  UNION ALL 
  SELECT 'factless rows without dim_season', COUNT(*) 
    FROM fact_team_season x LEFT JOIN dim_season s ON s.season_sk = x.season_sk WHERE s.season_sk IS NULL
  UNION ALL 
  SELECT 'duplicate grain keys (match_id, team_sk)', COUNT(*) 
    FROM (SELECT match_id, team_sk FROM fact_match_team GROUP BY 1, 2 HAVING COUNT(*) > 1) z
) c;

-- ----------------------------------------------------------------------------
-- 4. VOLUME: Rubric benchmarks (fact rows >= 10,000, dim rows >= 100)
-- ----------------------------------------------------------------------------
INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Volume', 
  'fact_match_team rows >= 10,000 (Rubric Req)', 
  '>=10000', 
  COUNT(*)::text,
  CASE WHEN COUNT(*) >= 10000 THEN 'PASS' ELSE 'FAIL' END 
FROM fact_match_team;

INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Volume', 
  'dim_date records >= 100 (Rubric Req)', 
  '>=100', 
  COUNT(*)::text,
  CASE WHEN COUNT(*) >= 100 THEN 'PASS' ELSE 'FAIL' END 
FROM dim_date;

INSERT INTO dq_results (category, check_name, expected, actual, status)
SELECT 
  'Volume', 
  'dim_team records >= 40 (Across 16 seasons)', 
  '>=40', 
  COUNT(*)::text,
  CASE WHEN COUNT(*) >= 40 THEN 'PASS' ELSE 'FAIL' END 
FROM dim_team;

SELECT check_id, category, check_name, expected, actual, status, run_at 
FROM dq_results 
ORDER BY check_id;
