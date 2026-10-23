# PL Insights — Star Schema Diagram

```mermaid
erDiagram
    %% Fact Table (Center)
    fact_match_team {
        bigint fact_match_team_sk PK
        string match_id
        int date_sk FK
        int season_sk FK
        int team_sk FK
        int opponent_team_sk FK
        int referee_sk FK
        int venue_sk FK
        boolean is_home
        int matchweek
        int goals_for
        int goals_against
        int points
        int is_win
        int is_draw
        int is_loss
        int is_clean_sheet
        int shots
        int shots_on_target
        int fouls_committed
        int yellow_cards
        int red_cards
    }

    %% Surrounding Dimensions
    dim_date {
        int date_sk PK
        date full_date
        int day_of_week
        string day_name
        int month
        string month_name
        int quarter
        int year
        boolean is_weekend
    }

    dim_season {
        int season_sk PK
        string season_code
        string season_years
        int start_year
        int end_year
    }

    dim_team {
        int team_sk PK
        string team_name
        string city
        string stadium
        int capacity
        boolean is_active
    }

    dim_referee {
        int referee_sk PK
        string referee_name
    }

    dim_venue {
        int venue_sk PK
        string stadium_name
        string city
        int capacity
    }

    %% Other Facts
    fact_team_matchweek_snapshot {
        bigint snapshot_sk PK
        int season_sk FK
        int team_sk FK
        int matchweek
        int cum_points
        int cum_goals_for
        int cum_goals_against
        int cum_goal_difference
        int league_position
    }

    fact_team_season {
        int team_season_sk PK
        int season_sk FK
        int team_sk FK
    }

    %% Relationships connected around the center fact
    dim_date ||--|{ fact_match_team : "date_sk"
    dim_season ||--|{ fact_match_team : "season_sk"
    dim_team ||--|{ fact_match_team : "team_sk"
    dim_team ||--|{ fact_match_team : "opponent_team_sk"
    dim_referee ||--|{ fact_match_team : "referee_sk"
    dim_venue ||--|{ fact_match_team : "venue_sk"

    dim_season ||--|{ fact_team_matchweek_snapshot : "season_sk"
    dim_team ||--|{ fact_team_matchweek_snapshot : "team_sk"
    dim_season ||--|{ fact_team_season : "season_sk"
    dim_team ||--|{ fact_team_season : "team_sk"