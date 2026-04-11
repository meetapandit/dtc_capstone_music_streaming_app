-- Gold: top artists per day
-- Ranked by play count within each day.  Use daily_rank <= N in Looker Studio
-- to build a "top 10 artists" chart filtered by date range.

SELECT
    event_date,
    artist,
    COUNT(*)                   AS play_count,
    COUNT(DISTINCT user_id)    AS unique_listeners,
    COUNT(DISTINCT song)       AS unique_songs,
    ROUND(SUM(duration_seconds) / 3600, 2) AS total_listening_hours,
    RANK() OVER (
        PARTITION BY event_date
        ORDER BY COUNT(*) DESC
    )                          AS daily_rank

FROM {{ ref('silver_listen_events') }}
WHERE artist IS NOT NULL

GROUP BY event_date, artist
