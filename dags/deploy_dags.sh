#!/usr/bin/env bash
# =============================================================================
# deploy_dags.sh
# Uploads the dbt project and Airflow DAG to the Composer GCS bucket.
# Run this from the repo root after any changes to dbt models or the DAG.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DAGS_BUCKET="gs://us-west1-dev-music-streamin-a51f2f4a-bucket"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# ---------------------------------------------------------------------------
# 1. Upload dbt project (models, macros, dbt_project.yml, profiles.yml)
#    Exclude target/, logs/, .venv/ — those are local artifacts
# ---------------------------------------------------------------------------
log "Uploading dbt project to ${DAGS_BUCKET}/dbt/ ..."
gcloud storage rsync \
  --recursive \
  --delete-unmatched-destination-objects \
  --exclude="target/.*|logs/.*|\.venv/.*|dbt_packages/.*" \
  "${REPO_ROOT}/dbt" \
  "${DAGS_BUCKET}/dbt"

log "dbt project uploaded."

# ---------------------------------------------------------------------------
# 2. Upload DAG file
# ---------------------------------------------------------------------------
log "Uploading DAG to ${DAGS_BUCKET}/ ..."
gcloud storage cp "${REPO_ROOT}/dags/music_streaming_dbt.py" "${DAGS_BUCKET}/"

log "DAG uploaded."
log ""
log "Done. Composer will pick up the DAG within ~1 minute."
log "View in Airflow UI via:"
log "  gcloud composer environments run dev-music-streaming-airflow --location us-west1 dags list"
