-- ============================================================================
-- Pitch-side (PL Insights) DWBI Final Project
-- Script: 03_ETL/facts.sql
-- Description: Load transaction, periodic snapshot, and factless fact tables
-- Deliverable: Fact Load Scripts & Business-to-Surrogate Key Lookup (15 marks)
-- ============================================================================

SET search_path = project_dw;

TRUNCATE fact_team_season, fact_team_matchweek_snapshot, fact_match_team RESTART IDENTITY;

-- ----------------------------------------------------------------------------
-- 1. fact_match_team (Transaction Fact: 12,160 rows = 2 rows x 6,080 matches)
-- ----------------------------------------------------------------------------
WITH staged_with_mw AS (
  SELECT 
    m.*,
    ROW_NUMBER() OVER (
      PARTITION BY m.season, m.team_name 
      ORDER BY m.match_date, m.match_id
    )::int AS matchweek
  FROM project_staging.stg_match_team m
)
INSERT INTO fact_match_team (
  match_id, date_sk, season_sk, team_sk, opponent_team_sk, referee_sk, venue_sk,
  is_home, matchweek, goals_for, goals_against, goal_diff, ht_goals_for, ht_goals_against,
  points, is_win, is_draw, is_loss, is_clean_sheet,
  shots, shots_on_target, corners, fouls_committed, yellow_cards, red_cards
)
SELECT 
  m.match_id,
  COALESCE(d.date_sk, -1),
  COALESCE(s.season_sk, -1),
  COALESCE(t.team_sk, -1),
  COALESCE(o.team_sk, -1),
  COALESCE(r.referee_sk, -1),
  COALESCE(v.venue_sk, -1),
  (m.venue_type = 'Home')::int AS is_home,
  m.matchweek,
  m.goals_for,
  m.goals_against,
  (m.goals_for - m.goals_against) AS goal_diff,
  m.ht_goals_for,
  m.ht_goals_against,
  CASE 
    WHEN m.goals_for > m.goals_against THEN 3
    WHEN m.goals_for = m.goals_against THEN 1
    ELSE 0 
  END AS points,
  (m.goals_for > m.goals_against)::int AS is_win,
  (m.goals_for = m.goals_against)::int AS is_draw,
  (m.goals_for < m.goals_against)::int AS is_loss,
  (m.goals_against = 0)::int AS is_clean_sheet,
  m.shots,
  m.shots_on_target,
  m.corners,
  m.fouls AS fouls_committed,
  m.yellow_cards,
  m.red_cards
FROM staged_with_mw m
LEFT JOIN dim_date    d  ON d.full_date    = m.match_date
LEFT JOIN dim_season  s  ON s.season_code  = m.season
LEFT JOIN dim_team    t  ON t.team_name    = m.team_name
LEFT JOIN dim_team    o  ON o.team_name    = m.opponent_name
LEFT JOIN dim_referee r  ON r.referee_name = m.referee
LEFT JOIN dim_team    ht ON ht.team_name   = CASE WHEN m.venue_type = 'Home' THEN m.team_name ELSE m.opponent_name END
LEFT JOIN dim_venue   v  ON v.stadium_name = ht.stadium AND v.city IS NOT DISTINCT FROM ht.city;

-- ----------------------------------------------------------------------------
-- 2. fact_team_matchweek_snapshot (Periodic Snapshot Fact)
-- ----------------------------------------------------------------------------
WITH base AS (
  SELECT 
    f.season_sk, 
    f.team_sk, 
    f.matchweek,
    f.points, 
    f.goals_for, 
    f.goals_against
  FROM fact_match_team f
), 
cum AS (
  SELECT 
    season_sk, 
    team_sk, 
    matchweek,
    SUM(points)        OVER w AS cp,
    SUM(goals_for)     OVER w AS gf,
    SUM(goals_against) OVER w AS ga,
    SUM(points) OVER (
      PARTITION BY season_sk, team_sk 
      ORDER BY matchweek 
      ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
    ) AS p5
  FROM base
  WINDOW w AS (PARTITION BY season_sk, team_sk ORDER BY matchweek)
)
INSERT INTO fact_team_matchweek_snapshot (
  season_sk, team_sk, matchweek, matches_played,
  cum_points, cum_goals_for, cum_goals_against, cum_goal_difference,
  league_position, points_last5
)
SELECT 
  season_sk, 
  team_sk, 
  matchweek, 
  matchweek AS matches_played,
  cp, 
  gf, 
  ga, 
  (gf - ga) AS cum_goal_difference,
  RANK() OVER (
    PARTITION BY season_sk, matchweek 
    ORDER BY cp DESC, (gf - ga) DESC, gf DESC
  ) AS league_position,
  p5 AS points_last5
FROM cum;

-- ----------------------------------------------------------------------------
-- 3. fact_team_season (Factless Fact: Team participation in each season)
-- ----------------------------------------------------------------------------
INSERT INTO fact_team_season (season_sk, team_sk)
SELECT DISTINCT season_sk, team_sk 
FROM fact_match_team
ORDER BY season_sk, team_sk;
