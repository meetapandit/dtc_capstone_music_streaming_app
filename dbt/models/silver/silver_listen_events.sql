-- Silver: listen_events
-- Cleans raw song play events: converts epoch ms → timestamp, adds derived
-- time dimensions, filters incomplete records, normalises level flag.

SELECT
    CAST(userId     AS INT64)  AS user_id,
    CAST(sessionId  AS INT64)  AS session_id,
    itemInSession               AS item_in_session,
    NULLIF(TRIM(artist), '')    AS artist,
    NULLIF(TRIM(song),   '')    AS song,
    CAST(length AS FLOAT64)     AS duration_seconds,
    LOWER(level)                AS level,
    level = 'paid'              AS is_paid,
    gender,
    NULLIF(TRIM(firstName), '') AS first_name,
    NULLIF(TRIM(lastName),  '') AS last_name,
    userAgent                   AS user_agent,
    registration,
    TIMESTAMP_MILLIS(ts)        AS event_timestamp,
    event_date,
    EXTRACT(HOUR        FROM TIMESTAMP_MILLIS(ts)) AS hour_of_day,
    EXTRACT(DAYOFWEEK   FROM TIMESTAMP_MILLIS(ts)) AS day_of_week,   -- 1=Sun
    EXTRACT(WEEK        FROM TIMESTAMP_MILLIS(ts)) AS week_of_year

FROM {{ source('bronze', 'listen_events') }}

WHERE userId IS NOT NULL
  AND song   IS NOT NULL
  AND artist IS NOT NULL
