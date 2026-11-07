-- ============================================================================
-- Pitch-side (PL Insights) DWBI Final Project
-- Script: 03_ETL/00_create_schemas.sql
-- Description: Create schemas and raw un-typed staging tables
-- Deliverable: Database Implementation (10 marks) / Staging Schema SQL
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS project_staging;
CREATE SCHEMA IF NOT EXISTS project_dw;
CREATE SCHEMA IF NOT EXISTS project_reporting;

-- Drop and recreate staging tables to ensure idempotency / re-runnability
DROP TABLE IF EXISTS project_staging.stg_matches CASCADE;
CREATE TABLE project_staging.stg_matches (
  "Date" text,
  "HomeTeam" text,
  "AwayTeam" text,
  "FTHG" text,
  "FTAG" text,
  "FTR" text,
  "HTHG" text,
  "HTAG" text,
  "HTR" text,
  "Referee" text,
  "HS" text,
  "AS" text,
  "HST" text,
  "AST" text,
  "HF" text,
  "AF" text,
  "HC" text,
  "AC" text,
  "HY" text,
  "AY" text,
  "HR" text,
  "AR" text,
  season text,
  source_file text
);

DROP TABLE IF EXISTS project_staging.stg_team_lookup CASCADE;
CREATE TABLE project_staging.stg_team_lookup (
  team_name text,
  city text,
  stadium text,
  capacity text
);
