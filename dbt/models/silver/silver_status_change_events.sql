-- Silver: status_change_events
-- Cleans subscription level-change events.
-- Derives change direction from the resulting level (paid = upgrade, free = downgrade/churn).

SELECT
    CAST(userId    AS INT64) AS user_id,
    CAST(sessionId AS INT64) AS session_id,
    itemInSession             AS item_in_session,
    LOWER(level)              AS level,
    CASE
        WHEN LOWER(level) = 'paid' THEN 'upgrade'
        WHEN LOWER(level) = 'free' THEN 'downgrade'
        ELSE 'other'
    END                       AS change_category,
    auth                      AS auth_status,
    gender,
    NULLIF(TRIM(firstName), '') AS first_name,
    NULLIF(TRIM(lastName),  '') AS last_name,
    registration,
    TIMESTAMP_MILLIS(ts)      AS event_timestamp,
    event_date,
    EXTRACT(HOUR      FROM TIMESTAMP_MILLIS(ts)) AS hour_of_day,
    EXTRACT(DAYOFWEEK FROM TIMESTAMP_MILLIS(ts)) AS day_of_week

FROM {{ source('bronze', 'status_change_events') }}
WHERE userId IS NOT NULL
