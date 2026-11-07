-- ============================================================================
-- Pitch-side (PL Insights) DWBI Final Project
-- Script: 04_Data_Warehouse/warehouse.sql
-- Description: DDL for Data Warehouse Schema (project_dw)
-- Deliverable: Database Implementation (10 marks) & DW Schema SQL
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS project_dw;
SET search_path = project_dw;

-- Drop tables in reverse dependency order for idempotency
DROP TABLE IF EXISTS fact_team_season CASCADE;
DROP TABLE IF EXISTS fact_team_matchweek_snapshot CASCADE;
DROP TABLE IF EXISTS fact_match_team CASCADE;
DROP TABLE IF EXISTS dim_venue CASCADE;
DROP TABLE IF EXISTS dim_referee CASCADE;
DROP TABLE IF EXISTS dim_team CASCADE;
DROP TABLE IF EXISTS dim_season CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

-- ----------------------------------------------------------------------------
-- 1. DIMENSION TABLES
-- ----------------------------------------------------------------------------

-- dim_date: Standard Date Dimension (Calendar hierarchy: Year > Quarter > Month > Day)
CREATE TABLE dim_date (
  date_sk int PRIMARY KEY,                   -- yyyymmdd format; -1 for unknown
  full_date date UNIQUE,                     -- business key
  day_of_week int,
  day_name varchar(10),
  month int,
  month_name varchar(10),
  quarter int,
  year int,
  is_weekend boolean
);

-- dim_season: Season dimension
CREATE TABLE dim_season (
  season_sk int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  season_code varchar(7) UNIQUE NOT NULL,    -- business key (e.g. '2023/24')
  season_years varchar(9),                   -- e.g. '2023-2024'
  start_year int,
  end_year int
);

-- dim_team: Team dimension enriched with external venue lookup
CREATE TABLE dim_team (
  team_sk int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  team_name varchar(50) UNIQUE NOT NULL,     -- business key (canonical name)
  city varchar(50),
  stadium varchar(80),
  capacity int,
  is_active boolean                          -- active in latest premier league season
);

-- dim_referee: Match official dimension
CREATE TABLE dim_referee (
  referee_sk int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  referee_name varchar(80) UNIQUE NOT NULL   -- business key
);

-- dim_venue: Stadium / Venue dimension
CREATE TABLE dim_venue (
  venue_sk int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  stadium_name varchar(80) NOT NULL,
  city varchar(50),
  capacity int,
  UNIQUE (stadium_name, city)
);

-- ----------------------------------------------------------------------------
-- 2. FACT TABLES
-- ----------------------------------------------------------------------------

-- fact_match_team: Transaction Fact (Grain: 1 row per team per match)
CREATE TABLE fact_match_team (
  fact_match_team_sk bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id varchar(100) NOT NULL,            -- degenerate key: season|date|home|away
  date_sk int NOT NULL REFERENCES dim_date(date_sk),
  season_sk int NOT NULL REFERENCES dim_season(season_sk),
  team_sk int NOT NULL REFERENCES dim_team(team_sk),
  opponent_team_sk int NOT NULL REFERENCES dim_team(team_sk), -- role-playing dimension
  referee_sk int NOT NULL REFERENCES dim_referee(referee_sk),
  venue_sk int NOT NULL REFERENCES dim_venue(venue_sk),
  is_home smallint NOT NULL,                 -- 1 for Home, 0 for Away (CUBE axis & home advantage)
  matchweek int NOT NULL,                    -- team's N-th match of season
  goals_for int,
  goals_against int,
  goal_diff int,
  ht_goals_for int,
  ht_goals_against int,
  points int,
  is_win smallint,
  is_draw smallint,
  is_loss smallint,
  is_clean_sheet smallint,
  shots int,
  shots_on_target int,
  corners int,
  fouls_committed int,
  yellow_cards int,
  red_cards int,
  UNIQUE (match_id, team_sk)
);

-- fact_team_matchweek_snapshot: Periodic Snapshot Fact (Grain: 1 row per team after matchweek N)
CREATE TABLE fact_team_matchweek_snapshot (
  snapshot_sk bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  season_sk int NOT NULL REFERENCES dim_season(season_sk),
  team_sk int NOT NULL REFERENCES dim_team(team_sk),
  matchweek int NOT NULL,
  matches_played int,
  cum_points int,                            -- semi-additive measure
  cum_goals_for int,
  cum_goals_against int,
  cum_goal_difference int,
  league_position int,
  points_last5 int,
  UNIQUE (season_sk, team_sk, matchweek)
);

-- fact_team_season: Factless Fact (Grain: 1 row per participating team per season)
CREATE TABLE fact_team_season (
  team_season_sk int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  season_sk int NOT NULL REFERENCES dim_season(season_sk),
  team_sk int NOT NULL REFERENCES dim_team(team_sk),
  UNIQUE (season_sk, team_sk)
);
