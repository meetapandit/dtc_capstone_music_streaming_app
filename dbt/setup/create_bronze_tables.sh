#!/usr/bin/env bash
# =============================================================================
# create_bronze_tables.sh
# Creates the BigQuery datasets and BigLake Iceberg external tables that point
# to the Iceberg tables written by Flink into GCS.  Run this once after
# `terraform apply` and before running dbt for the first time.
#
# These are BigLake external tables (format = 'ICEBERG'), NOT plain Parquet
# external tables.  The Cloud Resource Connection gives BigQuery a managed SA
# that can read AND write GCS, enabling full DML (INSERT/UPDATE/DELETE/MERGE)
# while keeping data in open Iceberg format on GCS.
#
# Prerequisites:
#   gcloud auth login
#   gcloud config set project dtc-capstone-491118
#   terraform apply   (creates the Cloud Resource Connection)
# =============================================================================

set -euo pipefail

PROJECT="dtc-capstone-491118"
LOCATION="us-west1"
BUCKET="dtc-capstone-491118-iceberg-warehouse"
WAREHOUSE="gs://${BUCKET}/warehouse/music_streaming"

# Fully-qualified connection reference output by `terraform output bq_connection_name`
# Format: PROJECT.REGION.CONNECTION_ID
CONNECTION="${PROJECT}.${LOCATION}.bigquery-iceberg-connection"

echo "==> Creating BigQuery datasets..."
for dataset in bronze silver gold; do
  bq --location="$LOCATION" mk --dataset \
    "${PROJECT}:${dataset}" 2>/dev/null || echo "    dataset $dataset already exists, skipping"
  echo "    dataset: $dataset"
done

echo ""
echo "==> Creating bronze BigLake Iceberg external tables..."
echo "    Connection: ${CONNECTION}"
echo ""

# ---------------------------------------------------------------------------
# listen_events
# BigQuery reads the Iceberg metadata directory to discover the latest
# snapshot.  Flink (Hadoop catalog) writes metadata under:
#   warehouse/music_streaming/<table>/metadata/v*.metadata.json
# ---------------------------------------------------------------------------
# Get the latest metadata.json for each table
LISTEN_META=$(gsutil ls "${WAREHOUSE}/listen_events/metadata/*.metadata.json" 2>/dev/null | sort -V | tail -1)
PAGE_META=$(gsutil ls "${WAREHOUSE}/page_view_events/metadata/*.metadata.json" 2>/dev/null | sort -V | tail -1)
AUTH_META=$(gsutil ls "${WAREHOUSE}/auth_events/metadata/*.metadata.json" 2>/dev/null | sort -V | tail -1)
STATUS_META=$(gsutil ls "${WAREHOUSE}/status_change_events/metadata/*.metadata.json" 2>/dev/null | sort -V | tail -1)

echo "    listen_events metadata:       ${LISTEN_META}"
echo "    page_view_events metadata:    ${PAGE_META}"
echo "    auth_events metadata:         ${AUTH_META}"
echo "    status_change_events metadata:${STATUS_META}"
echo ""

bq query --use_legacy_sql=false "
CREATE OR REPLACE EXTERNAL TABLE \`${PROJECT}.bronze.listen_events\`
WITH CONNECTION \`${CONNECTION}\`
OPTIONS (
  format = 'ICEBERG',
  uris   = ['${LISTEN_META}']
);"
echo "    listen_events done"

bq query --use_legacy_sql=false "
CREATE OR REPLACE EXTERNAL TABLE \`${PROJECT}.bronze.page_view_events\`
WITH CONNECTION \`${CONNECTION}\`
OPTIONS (
  format = 'ICEBERG',
  uris   = ['${PAGE_META}']
);"
echo "    page_view_events done"

bq query --use_legacy_sql=false "
CREATE OR REPLACE EXTERNAL TABLE \`${PROJECT}.bronze.auth_events\`
WITH CONNECTION \`${CONNECTION}\`
OPTIONS (
  format = 'ICEBERG',
  uris   = ['${AUTH_META}']
);"
echo "    auth_events done"

bq query --use_legacy_sql=false "
CREATE OR REPLACE EXTERNAL TABLE \`${PROJECT}.bronze.status_change_events\`
WITH CONNECTION \`${CONNECTION}\`
OPTIONS (
  format = 'ICEBERG',
  uris   = ['${STATUS_META}']
);"
echo "    status_change_events done"

echo ""
echo "==> All done. Verify in BigQuery console:"
echo "    https://console.cloud.google.com/bigquery?project=${PROJECT}"
echo ""
echo "Tables support full DML (INSERT/UPDATE/DELETE/MERGE) and time travel"
echo "via Iceberg snapshots.  Data stays in open Iceberg format on GCS."
echo ""
echo "Next: copy dbt/profiles.yml to ~/.dbt/profiles.yml, then run:"
echo "    cd dbt && dbt run"
