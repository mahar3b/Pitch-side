-- ============================================================================
-- Pitch-side (PL Insights) DWBI Final Project
-- Script: 03_ETL/staging.sql
-- Description: Clean, standardize, deduplicate, and unpivot staging data
-- Deliverable: Staging Schema SQL & Data Cleaning Report Source
-- ============================================================================

SET search_path = project_staging;

-- 1. Team name mapping table (raw CSV name -> standardised canonical name)
DROP TABLE IF EXISTS team_name_map CASCADE;
CREATE TABLE team_name_map (
  raw_name text PRIMARY KEY,
  team_name text NOT NULL
);

INSERT INTO team_name_map (raw_name, team_name) VALUES
  ('Arsenal', 'Arsenal'),
  ('Aston Villa', 'Aston Villa'),
  ('Birmingham', 'Birmingham City'),
  ('Blackburn', 'Blackburn Rovers'),
  ('Blackpool', 'Blackpool'),
  ('Bolton', 'Bolton Wanderers'),
  ('Bournemouth', 'AFC Bournemouth'),
  ('Brentford', 'Brentford'),
  ('Brighton', 'Brighton & Hove Albion'),
  ('Burnley', 'Burnley'),
  ('Cardiff', 'Cardiff City'),
  ('Chelsea', 'Chelsea'),
  ('Crystal Palace', 'Crystal Palace'),
  ('Everton', 'Everton'),
  ('Fulham', 'Fulham'),
  ('Huddersfield', 'Huddersfield Town'),
  ('Hull', 'Hull City'),
  ('Ipswich', 'Ipswich Town'),
  ('Leeds', 'Leeds United'),
  ('Leicester', 'Leicester City'),
  ('Liverpool', 'Liverpool'),
  ('Luton', 'Luton Town'),
  ('Man City', 'Manchester City'),
  ('Man United', 'Manchester United'),
  ('Middlesbrough', 'Middlesbrough'),
  ('Newcastle', 'Newcastle United'),
  ('Norwich', 'Norwich City'),
  ('Nott''m Forest', 'Nottingham Forest'),
  ('QPR', 'Queens Park Rangers'),
  ('Reading', 'Reading'),
  ('Sheffield United', 'Sheffield United'),
  ('Southampton', 'Southampton'),
  ('Stoke', 'Stoke City'),
  ('Sunderland', 'Sunderland'),
  ('Swansea', 'Swansea City'),
  ('Tottenham', 'Tottenham Hotspur'),
  ('Watford', 'Watford'),
  ('West Brom', 'West Bromwich Albion'),
  ('West Ham', 'West Ham United'),
  ('Wigan', 'Wigan Athletic'),
  ('Wolves', 'Wolverhampton Wanderers');

-- 2. Clean: parse dates, convert types, standardize team names, handle NULL referees, deduplicate
DROP TABLE IF EXISTS stg_matches_clean CASCADE;
CREATE TABLE stg_matches_clean AS
WITH typed AS (
  SELECT 
    season, 
    source_file,
    CASE 
      WHEN TRIM("Date") ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN to_date(TRIM("Date"), 'DD/MM/YYYY')
      WHEN TRIM("Date") ~ '^\d{1,2}/\d{1,2}/\d{2}$'  THEN to_date(TRIM("Date"), 'DD/MM/YY') 
    END AS match_date,
    TRIM("HomeTeam") AS home_raw, 
    TRIM("AwayTeam") AS away_raw,
    NULLIF(TRIM("FTHG"), '')::int AS fthg, 
    NULLIF(TRIM("FTAG"), '')::int AS ftag,
    NULLIF(TRIM("HTHG"), '')::int AS hthg, 
    NULLIF(TRIM("HTAG"), '')::int AS htag,
    NULLIF(TRIM("HS"), '')::int   AS h_shots,   
    NULLIF(TRIM("AS"), '')::int   AS a_shots,
    NULLIF(TRIM("HST"), '')::int  AS h_sot,     
    NULLIF(TRIM("AST"), '')::int  AS a_sot,
    NULLIF(TRIM("HF"), '')::int   AS h_fouls,   
    NULLIF(TRIM("AF"), '')::int   AS a_fouls,
    NULLIF(TRIM("HC"), '')::int   AS h_corners, 
    NULLIF(TRIM("AC"), '')::int   AS a_corners,
    NULLIF(TRIM("HY"), '')::int   AS h_yellow,  
    NULLIF(TRIM("AY"), '')::int   AS a_yellow,
    NULLIF(TRIM("HR"), '')::int   AS h_red,     
    NULLIF(TRIM("AR"), '')::int   AS a_red,
    COALESCE(NULLIF(INITCAP(TRIM("Referee")), ''), 'Unknown') AS referee
  FROM stg_matches
), 
mapped AS (
  SELECT 
    t.*,
    COALESCE(h.team_name, INITCAP(t.home_raw)) AS home_team,
    COALESCE(a.team_name, INITCAP(t.away_raw)) AS away_team
  FROM typed t
  LEFT JOIN team_name_map h ON h.raw_name = t.home_raw
  LEFT JOIN team_name_map a ON a.raw_name = t.away_raw
)
SELECT DISTINCT ON (season, match_date, home_team, away_team) *
FROM mapped
WHERE match_date IS NOT NULL 
  AND home_team <> '' 
  AND away_team <> ''
  AND fthg IS NOT NULL 
  AND ftag IS NOT NULL
ORDER BY season, match_date, home_team, away_team, source_file;

-- 3. Cleaning log (audit trail and evidence for Data Cleaning Report)
DROP TABLE IF EXISTS cleaning_log CASCADE;
CREATE TABLE cleaning_log AS
SELECT 'raw rows ingested' AS metric, COUNT(*) AS count_value FROM stg_matches
UNION ALL SELECT 'clean rows after transformation', COUNT(*) FROM stg_matches_clean
UNION ALL SELECT 'rows removed (corrupted/incomplete/duplicate)',
  (SELECT COUNT(*) FROM stg_matches) - (SELECT COUNT(*) FROM stg_matches_clean)
UNION ALL SELECT '2-digit year dates converted', COUNT(*) FROM stg_matches WHERE TRIM("Date") ~ '^\d{1,2}/\d{1,2}/\d{2}$'
UNION ALL SELECT 'NULL/empty referee mapped to Unknown', COUNT(*) FROM stg_matches WHERE NULLIF(TRIM("Referee"), '') IS NULL
UNION ALL SELECT 'raw home team names remapped', COUNT(*) FROM stg_matches s JOIN team_name_map m ON m.raw_name = TRIM(s."HomeTeam") WHERE m.raw_name <> m.team_name
UNION ALL SELECT 'distinct standardized teams', COUNT(DISTINCT t) FROM (
  SELECT home_team AS t FROM stg_matches_clean UNION SELECT away_team FROM stg_matches_clean) x;

-- 4. Unpivot matches: 1 match row -> 2 team-centric performance rows
DROP TABLE IF EXISTS stg_match_team CASCADE;
CREATE TABLE stg_match_team AS
SELECT 
  season || '|' || match_date || '|' || home_team || '|' || away_team AS match_id,
  season, 
  match_date, 
  home_team AS team_name, 
  away_team AS opponent_name,
  'Home'::text AS venue_type, 
  referee,
  fthg AS goals_for, 
  ftag AS goals_against, 
  hthg AS ht_goals_for, 
  htag AS ht_goals_against,
  h_shots AS shots, 
  h_sot AS shots_on_target, 
  h_corners AS corners, 
  h_fouls AS fouls,
  h_yellow AS yellow_cards, 
  h_red AS red_cards
FROM stg_matches_clean
UNION ALL
SELECT 
  season || '|' || match_date || '|' || home_team || '|' || away_team,
  season, 
  match_date, 
  away_team, 
  home_team, 
  'Away', 
  referee,
  ftag, 
  fthg, 
  htag, 
  hthg,
  a_shots, 
  a_sot, 
  a_corners, 
  a_fouls, 
  a_yellow, 
  a_red
FROM stg_matches_clean;
