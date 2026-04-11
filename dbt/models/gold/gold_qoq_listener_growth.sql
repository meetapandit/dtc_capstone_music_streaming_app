-- Gold: Quarter-over-Quarter listener growth
-- Counts distinct users per quarter from silver, then computes QoQ growth %.

WITH quarterly_users AS (
    SELECT
        DATE_TRUNC(event_date, QUARTER)    AS quarter_start,
        FORMAT_DATE('%Y-Q%Q', event_date)  AS quarter_label,
        COUNT(DISTINCT user_id)            AS unique_listeners
    FROM {{ ref('silver_listen_events') }}
    GROUP BY 1, 2
),

with_growth AS (
    SELECT
        quarter_start,
        quarter_label,
        unique_listeners,
        LAG(unique_listeners) OVER (ORDER BY quarter_start) AS prev_quarter_listeners,
        ROUND(
            SAFE_DIVIDE(
                unique_listeners - LAG(unique_listeners) OVER (ORDER BY quarter_start),
                LAG(unique_listeners) OVER (ORDER BY quarter_start)
            ) * 100,
        1) AS qoq_growth_pct
    FROM quarterly_users
)

SELECT
    quarter_start,
    quarter_label,
    unique_listeners,
    prev_quarter_listeners,
    qoq_growth_pct,
    CASE
        WHEN qoq_growth_pct > 0 THEN 'growth'
        WHEN qoq_growth_pct < 0 THEN 'decline'
        WHEN qoq_growth_pct = 0 THEN 'flat'
        ELSE 'first quarter'
    END AS trend
FROM with_growth
ORDER BY quarter_start
