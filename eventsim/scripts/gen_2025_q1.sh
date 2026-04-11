#!/usr/bin/env bash
# Generates 2025 Q1 eventsim data using Docker (Java 11, amd64)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/eventsim/output"
CONFIG_DIR="${REPO_ROOT}/eventsim/config"

mkdir -p "$OUTPUT_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting 2025 Q1 generation..."

docker run --platform linux/amd64 --rm \
  -v "${OUTPUT_DIR}:/output" \
  -v "${CONFIG_DIR}:/config" \
  --entrypoint /bin/bash \
  eventsim -c "
    cd /opt/eventsim && \
    java -XX:+UseG1GC -Xmx4G -jar eventsim-assembly-2.0.jar \
      --config /config/control-config.json \
      --tag control \
      -n 10000 \
      --start-time '2025-01-01T00:00:00' \
      --end-time   '2025-03-31T23:59:59' \
      --growth-rate 0.30 \
      --userid 1 \
      --randomseed 1 \
      /output/2025_Q1_control.json
  "

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done. Output: ${OUTPUT_DIR}/2025_Q1_control.json"
