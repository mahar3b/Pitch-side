-- ============================================================================
-- Pitch-side (PL Insights) DWBI Final Project
-- Script: 03_ETL/dimensions.sql
-- Description: Populate dimension tables with surrogate keys and unknown members (-1)
-- Deliverable: Dimension Load Scripts & Surrogate Keys (5 marks)
-- ============================================================================

SET search_path = project_dw;

-- Truncate existing data to maintain full idempotency
TRUNCATE fact_team_season, fact_team_matchweek_snapshot, fact_match_team,
         dim_venue, dim_referee, dim_team, dim_season, dim_date RESTART IDENTITY CASCADE;

-- ----------------------------------------------------------------------------
-- 1. dim_date: Generated calendar (2010-07-01 to 2026-06-30 = 5,844 records)
-- ----------------------------------------------------------------------------
INSERT INTO dim_date (date_sk, full_date, day_of_week, day_name, month, month_name, quarter, year, is_weekend)
VALUES (-1, NULL, NULL, 'Unknown', NULL, 'Unknown', NULL, NULL, FALSE);

INSERT INTO dim_date (date_sk, full_date, day_of_week, day_name, month, month_name, quarter, year, is_weekend)
SELECT 
  to_char(d, 'YYYYMMDD')::int AS date_sk,
  d::date AS full_date,
  EXTRACT(ISODOW FROM d)::int AS day_of_week,
  TRIM(to_char(d, 'Day')) AS day_name,
  EXTRACT(MONTH FROM d)::int AS month,
  TRIM(to_char(d, 'Month')) AS month_name,
  EXTRACT(QUARTER FROM d)::int AS quarter,
  EXTRACT(YEAR FROM d)::int AS year,
  EXTRACT(ISODOW FROM d) IN (6, 7) AS is_weekend
FROM generate_series('2010-07-01'::date, '2026-06-30'::date, interval '1 day') AS d;

-- ----------------------------------------------------------------------------
-- 2. dim_season
-- ----------------------------------------------------------------------------
INSERT INTO dim_season (season_sk, season_code, season_years, start_year, end_year)
OVERRIDING SYSTEM VALUE VALUES (-1, 'Unknown', 'Unknown', NULL, NULL);

INSERT INTO dim_season (season_code, season_years, start_year, end_year)
SELECT DISTINCT 
  season, 
  LEFT(season, 4) || '-' || (LEFT(season, 4)::int + 1)::text,
  LEFT(season, 4)::int, 
  LEFT(season, 4)::int + 1
FROM project_staging.stg_matches_clean 
ORDER BY 1;

-- ----------------------------------------------------------------------------
-- 3. dim_team (Joined with 2nd source: stg_team_lookup)
-- ----------------------------------------------------------------------------
INSERT INTO dim_team (team_sk, team_name, city, stadium, capacity, is_active)
OVERRIDING SYSTEM VALUE VALUES (-1, 'Unknown', 'Unknown', 'Unknown', NULL, FALSE);

INSERT INTO dim_team (team_name, city, stadium, capacity, is_active)
SELECT 
  t.team_name, 
  l.city, 
  l.stadium, 
  NULLIF(l.capacity, '')::int,
  (t.team_name IN (SELECT DISTINCT team_name FROM project_staging.stg_match_team WHERE season = '2025/26')) AS is_active
FROM (SELECT DISTINCT team_name FROM project_staging.stg_match_team) t
LEFT JOIN project_staging.stg_team_lookup l ON l.team_name = t.team_name
ORDER BY t.team_name;

-- ----------------------------------------------------------------------------
-- 4. dim_referee
-- ----------------------------------------------------------------------------
INSERT INTO dim_referee (referee_sk, referee_name)
OVERRIDING SYSTEM VALUE VALUES (-1, 'Unknown');

INSERT INTO dim_referee (referee_name)
SELECT DISTINCT referee 
FROM project_staging.stg_matches_clean 
WHERE referee <> 'Unknown' 
ORDER BY 1;

-- ----------------------------------------------------------------------------
-- 5. dim_venue
-- ----------------------------------------------------------------------------
INSERT INTO dim_venue (venue_sk, stadium_name, city, capacity)
OVERRIDING SYSTEM VALUE VALUES (-1, 'Unknown', 'Unknown', NULL);

INSERT INTO dim_venue (stadium_name, city, capacity)
SELECT DISTINCT ON (stadium, city) 
  stadium, 
  city, 
  capacity
FROM dim_team 
WHERE stadium IS NOT NULL AND stadium <> 'Unknown'
ORDER BY stadium, city, capacity DESC;
