-- pipeline_status
-- Written by the DAG after dbt_test_gold passes.
-- Looker datagroup polls this table to know when gold is safe to serve.
-- One row per gold table, updated on every successful pipeline run.

{{ config(materialized='table', schema='gold') }}

SELECT
    table_name,
    refreshed_at,
    is_ready,
    rows_loaded
FROM (
    SELECT 'gold_daily_listening_stats'    AS table_name,
           CURRENT_TIMESTAMP()             AS refreshed_at,
           TRUE                            AS is_ready,
           COUNT(*)                        AS rows_loaded
    FROM {{ ref('gold_daily_listening_stats') }}

    UNION ALL

    SELECT 'gold_top_artists_daily',
           CURRENT_TIMESTAMP(),
           TRUE,
           COUNT(*)
    FROM {{ ref('gold_top_artists_daily') }}

    UNION ALL

    SELECT 'gold_top_songs_daily',
           CURRENT_TIMESTAMP(),
           TRUE,
           COUNT(*)
    FROM {{ ref('gold_top_songs_daily') }}

    UNION ALL

    SELECT 'gold_hourly_listening_heatmap',
           CURRENT_TIMESTAMP(),
           TRUE,
           COUNT(*)
    FROM {{ ref('gold_hourly_listening_heatmap') }}

    UNION ALL

    SELECT 'gold_user_activity_daily',
           CURRENT_TIMESTAMP(),
           TRUE,
           COUNT(*)
    FROM {{ ref('gold_user_activity_daily') }}

    UNION ALL

    SELECT 'gold_qoq_listener_growth',
           CURRENT_TIMESTAMP(),
           TRUE,
           COUNT(*)
    FROM {{ ref('gold_qoq_listener_growth') }}
)
