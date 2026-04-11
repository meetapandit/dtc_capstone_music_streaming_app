-- Gold: user engagement per day
-- One row per user per day. Combines listen, page-view, and status-change
-- signals to give a full picture of user activity.

WITH listens AS (
    SELECT
        event_date,
        user_id,
        ANY_VALUE(first_name)               AS first_name,
        ANY_VALUE(last_name)                AS last_name,
        ANY_VALUE(gender)                   AS gender,
        ANY_VALUE(level)                    AS level,
        COUNT(*)                            AS play_count,
        COUNT(DISTINCT session_id)          AS sessions_with_plays,
        COUNT(DISTINCT artist)              AS unique_artists,
        ROUND(SUM(duration_seconds) / 60, 2) AS total_listening_minutes
    FROM {{ ref('silver_listen_events') }}
    GROUP BY event_date, user_id
),

page_views AS (
    SELECT
        event_date,
        user_id,
        COUNT(*)                            AS page_view_count,
        COUNT(DISTINCT page)                AS unique_pages_visited,
        COUNT(DISTINCT session_id)          AS sessions_with_page_views
    FROM {{ ref('silver_page_view_events') }}
    GROUP BY event_date, user_id
),

status_changes AS (
    SELECT
        event_date,
        user_id,
        COUNTIF(change_category = 'upgrade')   AS upgrade_count,
        COUNTIF(change_category = 'downgrade') AS downgrade_count,
        COUNTIF(change_category = 'churn')     AS churn_events
    FROM {{ ref('silver_status_change_events') }}
    GROUP BY event_date, user_id
)

SELECT
    l.event_date,
    l.user_id,
    l.first_name,
    l.last_name,
    l.gender,
    l.level,
    l.play_count,
    l.sessions_with_plays,
    l.unique_artists,
    l.total_listening_minutes,
    COALESCE(p.page_view_count,          0) AS page_view_count,
    COALESCE(p.unique_pages_visited,     0) AS unique_pages_visited,
    COALESCE(p.sessions_with_page_views, 0) AS sessions_with_page_views,
    COALESCE(s.upgrade_count,            0) AS upgrade_count,
    COALESCE(s.downgrade_count,          0) AS downgrade_count,
    COALESCE(s.churn_events,             0) AS churn_events

FROM listens l
LEFT JOIN page_views      p USING (event_date, user_id)
LEFT JOIN status_changes  s USING (event_date, user_id)
