-- Silver: page_view_events
-- Cleans page navigation events; excludes system/error pages that aren't
-- meaningful for user-behaviour analysis.

WITH cleaned AS (
    SELECT
        CAST(userId    AS INT64) AS user_id,
        CAST(sessionId AS INT64) AS session_id,
        itemInSession             AS item_in_session,
        NULLIF(TRIM(page), '')    AS page,
        LOWER(level)              AS level,
        level = 'paid'            AS is_paid,
        gender,
        NULLIF(TRIM(firstName), '') AS first_name,
        NULLIF(TRIM(lastName),  '') AS last_name,
        NULLIF(TRIM(userAgent), '') AS user_agent,
        TIMESTAMP_MILLIS(ts)      AS event_timestamp,
        event_date,
        EXTRACT(HOUR      FROM TIMESTAMP_MILLIS(ts)) AS hour_of_day,
        EXTRACT(DAYOFWEEK FROM TIMESTAMP_MILLIS(ts)) AS day_of_week,
        `method`                  AS http_method,
        `status`                  AS http_status,
        auth,
        registration

    FROM {{ source('bronze', 'page_view_events') }}
    WHERE userId IS NOT NULL
)

SELECT *
FROM cleaned
-- Keep only user-facing pages for behavioural analysis
WHERE page NOT IN ('Error', 'Upgrade', 'Submit Upgrade', 'Submit Downgrade',
                   'Cancellation Confirmation', 'Save Settings', 'Submit Registration')
