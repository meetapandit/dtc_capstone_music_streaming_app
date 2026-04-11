-- Silver: auth_events
-- Cleans authentication events. Uses the boolean `success` field from eventsim.

SELECT
    CAST(userId    AS INT64) AS user_id,
    CAST(sessionId AS INT64) AS session_id,
    itemInSession             AS item_in_session,
    success                   AS is_successful,
    LOWER(level)              AS level,
    level = 'paid'            AS is_paid,
    gender,
    NULLIF(TRIM(firstName), '') AS first_name,
    NULLIF(TRIM(lastName),  '') AS last_name,
    registration,
    TIMESTAMP_MILLIS(ts)      AS event_timestamp,
    event_date,
    EXTRACT(HOUR      FROM TIMESTAMP_MILLIS(ts)) AS hour_of_day,
    EXTRACT(DAYOFWEEK FROM TIMESTAMP_MILLIS(ts)) AS day_of_week

FROM {{ source('bronze', 'auth_events') }}
WHERE userId IS NOT NULL
