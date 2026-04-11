-- =============================================================================
-- Flink SQL Job: Kafka → Iceberg (raw copy, no transformation)
-- Field names match actual eventsim JSON output.
-- Reserved words (method, status, level, etc.) are backtick-quoted.
-- =============================================================================

SET 'execution.checkpointing.interval'  = '60s';
SET 'execution.checkpointing.mode'      = 'EXACTLY_ONCE';
SET 'parallelism.default'               = '1';
SET 'table.exec.source.idle-timeout'    = '30s';

CREATE CATALOG iceberg_catalog WITH (
  'type'             = 'iceberg',
  'catalog-type'     = 'hadoop',
  'warehouse'        = 'gs://dtc-capstone-491118-iceberg-warehouse/warehouse',
  'default-database' = 'music_streaming'
);

USE CATALOG iceberg_catalog;
CREATE DATABASE IF NOT EXISTS music_streaming;
USE music_streaming;

-- ---------------------------------------------------------------------------
-- Kafka source tables — field names match eventsim JSON exactly
-- ---------------------------------------------------------------------------

CREATE TEMPORARY TABLE kafka_listen_events (
  artist        STRING,
  auth          STRING,
  firstName     STRING,
  gender        STRING,
  itemInSession INT,
  lastName      STRING,
  duration      DOUBLE,        -- eventsim uses "duration", not "length"
  `level`       STRING,
  userAgent     STRING,
  registration  BIGINT,
  sessionId     INT,
  song          STRING,
  ts            BIGINT,
  userId        INT,
  event_time    AS TO_TIMESTAMP_LTZ(ts, 3),
  WATERMARK FOR event_time AS event_time - INTERVAL '30' SECOND
) WITH (
  'connector'                    = 'kafka',
  'topic'                        = 'listen-events',
  'properties.bootstrap.servers' = 'music-streaming-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092',
  'properties.group.id'          = 'flink-iceberg-raw',
  'scan.startup.mode'            = 'earliest-offset',
  'format'                       = 'json',
  'json.ignore-parse-errors'     = 'true'
);

CREATE TEMPORARY TABLE kafka_page_view_events (
  auth          STRING,
  firstName     STRING,
  gender        STRING,
  itemInSession INT,
  lastName      STRING,
  `level`       STRING,
  `method`      STRING,
  `page`        STRING,
  registration  BIGINT,
  sessionId     INT,
  `status`      INT,
  ts            BIGINT,
  userId        INT,
  userAgent     STRING,
  artist        STRING,
  song          STRING,
  duration      DOUBLE,
  event_time    AS TO_TIMESTAMP_LTZ(ts, 3),
  WATERMARK FOR event_time AS event_time - INTERVAL '30' SECOND
) WITH (
  'connector'                    = 'kafka',
  'topic'                        = 'page-view-events',
  'properties.bootstrap.servers' = 'music-streaming-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092',
  'properties.group.id'          = 'flink-iceberg-raw',
  'scan.startup.mode'            = 'earliest-offset',
  'format'                       = 'json',
  'json.ignore-parse-errors'     = 'true'
);

CREATE TEMPORARY TABLE kafka_auth_events (
  ts            BIGINT,
  sessionId     INT,
  `level`       STRING,
  itemInSession INT,
  userId        INT,
  lastName      STRING,
  firstName     STRING,
  gender        STRING,
  registration  BIGINT,
  success       BOOLEAN,
  event_time    AS TO_TIMESTAMP_LTZ(ts, 3),
  WATERMARK FOR event_time AS event_time - INTERVAL '30' SECOND
) WITH (
  'connector'                    = 'kafka',
  'topic'                        = 'auth-events',
  'properties.bootstrap.servers' = 'music-streaming-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092',
  'properties.group.id'          = 'flink-iceberg-raw',
  'scan.startup.mode'            = 'earliest-offset',
  'format'                       = 'json',
  'json.ignore-parse-errors'     = 'true'
);

CREATE TEMPORARY TABLE kafka_status_change_events (
  auth          STRING,
  firstName     STRING,
  gender        STRING,
  itemInSession INT,
  lastName      STRING,
  `level`       STRING,
  registration  BIGINT,
  sessionId     INT,
  ts            BIGINT,
  userId        INT,
  event_time    AS TO_TIMESTAMP_LTZ(ts, 3),
  WATERMARK FOR event_time AS event_time - INTERVAL '30' SECOND
) WITH (
  'connector'                    = 'kafka',
  'topic'                        = 'status-change-events',
  'properties.bootstrap.servers' = 'music-streaming-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092',
  'properties.group.id'          = 'flink-iceberg-raw',
  'scan.startup.mode'            = 'earliest-offset',
  'format'                       = 'json',
  'json.ignore-parse-errors'     = 'true'
);

-- ---------------------------------------------------------------------------
-- Iceberg sink tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS listen_events (
  artist        STRING,
  auth          STRING,
  firstName     STRING,
  gender        STRING,
  itemInSession INT,
  lastName      STRING,
  `length`      DOUBLE,        -- stored as "length" in Iceberg (industry standard name)
  `level`       STRING,
  userAgent     STRING,
  registration  BIGINT,
  sessionId     INT,
  song          STRING,
  ts            BIGINT,
  userId        INT,
  event_date    DATE
) PARTITIONED BY (event_date)
WITH ('write.format.default' = 'parquet');

CREATE TABLE IF NOT EXISTS page_view_events (
  auth          STRING,
  firstName     STRING,
  gender        STRING,
  itemInSession INT,
  lastName      STRING,
  `level`       STRING,
  `method`      STRING,
  `page`        STRING,
  registration  BIGINT,
  sessionId     INT,
  `status`      INT,
  ts            BIGINT,
  userId        INT,
  userAgent     STRING,
  artist        STRING,
  song          STRING,
  `length`      DOUBLE,
  event_date    DATE
) PARTITIONED BY (event_date)
WITH ('write.format.default' = 'parquet');

CREATE TABLE IF NOT EXISTS auth_events (
  ts            BIGINT,
  sessionId     INT,
  `level`       STRING,
  itemInSession INT,
  userId        INT,
  lastName      STRING,
  firstName     STRING,
  gender        STRING,
  registration  BIGINT,
  success       BOOLEAN,
  event_date    DATE
) PARTITIONED BY (event_date)
WITH ('write.format.default' = 'parquet');

CREATE TABLE IF NOT EXISTS status_change_events (
  auth          STRING,
  firstName     STRING,
  gender        STRING,
  itemInSession INT,
  lastName      STRING,
  `level`       STRING,
  registration  BIGINT,
  sessionId     INT,
  ts            BIGINT,
  userId        INT,
  event_date    DATE
) PARTITIONED BY (event_date)
WITH ('write.format.default' = 'parquet');

-- ---------------------------------------------------------------------------
-- Stream inserts
-- ---------------------------------------------------------------------------

INSERT INTO listen_events
SELECT artist, auth, firstName, gender, itemInSession, lastName,
       duration, `level`, userAgent, registration,
       sessionId, song, ts, userId,
       CAST(event_time AS DATE) AS event_date
FROM kafka_listen_events;

INSERT INTO page_view_events
SELECT auth, firstName, gender, itemInSession, lastName, `level`,
       `method`, `page`, registration, sessionId, `status`,
       ts, userId, userAgent, artist, song, duration,
       CAST(event_time AS DATE) AS event_date
FROM kafka_page_view_events;

INSERT INTO auth_events
SELECT ts, sessionId, `level`, itemInSession, userId,
       lastName, firstName, gender, registration, success,
       CAST(event_time AS DATE) AS event_date
FROM kafka_auth_events;

INSERT INTO status_change_events
SELECT auth, firstName, gender, itemInSession, lastName, `level`,
       registration, sessionId, ts, userId,
       CAST(event_time AS DATE) AS event_date
FROM kafka_status_change_events;
