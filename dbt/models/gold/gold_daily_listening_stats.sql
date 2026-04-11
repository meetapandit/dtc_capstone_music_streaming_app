-- Gold: daily listening stats
-- One row per day. Answers: how much music was streamed, by how many users,
-- and what was the paid vs free split?  Primary Looker Studio time-series table.

SELECT
    event_date,
    COUNT(*)                            AS total_plays,
    COUNT(DISTINCT user_id)             AS unique_listeners,
    COUNT(DISTINCT artist)              AS unique_artists,
    COUNT(DISTINCT song)                AS unique_songs,
    COUNT(DISTINCT session_id)          AS unique_sessions,
    ROUND(SUM(duration_seconds) / 3600, 2)  AS total_listening_hours,
    ROUND(AVG(duration_seconds) / 60,   2)  AS avg_track_duration_minutes,
    COUNTIF(is_paid)                    AS paid_plays,
    COUNTIF(NOT is_paid)                AS free_plays,
    ROUND(SAFE_DIVIDE(COUNTIF(is_paid), COUNT(*)) * 100, 1) AS paid_play_pct

FROM {{ ref('silver_listen_events') }}

GROUP BY event_date
ORDER BY event_date
