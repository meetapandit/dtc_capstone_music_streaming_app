#!/usr/bin/env bash
# Generates eventsim data for a single quarter using Docker (Java 11, amd64).
# Runs control and test threads in parallel, matching generate_events.sh design.
#
# Usage: gen_quarter.sh <YEAR_QN> <START_DATE> <END_DATE>
# Example: gen_quarter.sh 2025_Q1 2025-01-01 2025-03-31
set -euo pipefail

LABEL="${1:?Usage: gen_quarter.sh <YEAR_QN> <START_DATE> <END_DATE>}"
START_DATE="${2:?}"
END_DATE="${3:?}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/eventsim/output"
CONFIG_DIR="${REPO_ROOT}/eventsim/config"

TOTAL_USERS=10000
GROWTH_RATE=0.30

mkdir -p "$OUTPUT_DIR"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

run_thread() {
    local tag="$1"
    local seed="$2"
    local userid="$3"
    local outfile="/output/${LABEL}_${tag}.json"

    log "Starting [$tag] ${LABEL} | ${START_DATE} → ${END_DATE} | userid_start=${userid}"

    docker run --platform linux/amd64 --rm \
      -v "${OUTPUT_DIR}:/output" \
      -v "${CONFIG_DIR}:/config" \
      --entrypoint /bin/bash \
      eventsim -c "
        cd /opt/eventsim && \
        java -XX:+UseG1GC -Xmx4G -jar eventsim-assembly-2.0.jar \
          --config /config/${tag}-config.json \
          --tag ${tag} \
          -n ${TOTAL_USERS} \
          --start-time '${START_DATE}T00:00:00' \
          --end-time   '${END_DATE}T23:59:59' \
          --growth-rate ${GROWTH_RATE} \
          --userid ${userid} \
          --randomseed ${seed} \
          ${outfile}
      " >> "${OUTPUT_DIR}/generate.log" 2>&1

    log "Done    [$tag] ${LABEL} → ${OUTPUT_DIR}/${LABEL}_${tag}.json"
}

# Run control (users 1–10000, seed 1) and test (users 10001–20000, seed 2) in parallel
run_thread "control" 1 1                        &
CTRL_PID=$!
run_thread "test"    2 $((TOTAL_USERS + 1))     &
TEST_PID=$!

FAILED=0
wait "$CTRL_PID" || { log "ERROR: control thread failed"; FAILED=$((FAILED+1)); }
wait "$TEST_PID" || { log "ERROR: test thread failed";    FAILED=$((FAILED+1)); }

if [[ $FAILED -eq 0 ]]; then
    log "Both threads completed for ${LABEL}."
else
    log "ERROR: ${FAILED} thread(s) failed. Check ${OUTPUT_DIR}/generate.log"
    exit 1
fi
