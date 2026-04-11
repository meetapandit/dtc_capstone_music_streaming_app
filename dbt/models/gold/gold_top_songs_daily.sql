-- Gold: top songs per day
-- Ranked by play count within each day.

SELECT
    event_date,
    song,
    artist,
    COUNT(*)                   AS play_count,
    COUNT(DISTINCT user_id)    AS unique_listeners,
    ROUND(AVG(duration_seconds) / 60, 2) AS avg_duration_minutes,
    RANK() OVER (
        PARTITION BY event_date
        ORDER BY COUNT(*) DESC
    )                          AS daily_rank

FROM {{ ref('silver_listen_events') }}
WHERE song IS NOT NULL

GROUP BY event_date, song, artist
