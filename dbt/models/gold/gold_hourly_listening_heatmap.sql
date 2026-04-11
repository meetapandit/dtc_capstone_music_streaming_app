-- Gold: play count by hour-of-day and day-of-week
-- Feeds a heatmap chart in Looker Studio showing peak listening times.
-- day_of_week: 1=Sunday … 7=Saturday (BigQuery EXTRACT convention)

SELECT
    day_of_week,
    hour_of_day,
    COUNT(*)                   AS play_count,
    COUNT(DISTINCT user_id)    AS unique_listeners,
    ROUND(AVG(duration_seconds) / 60, 2) AS avg_duration_minutes

FROM {{ ref('silver_listen_events') }}

GROUP BY day_of_week, hour_of_day
ORDER BY day_of_week, hour_of_day
