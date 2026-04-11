#!/usr/bin/env bash
# =============================================================================
# generate_events_docker.sh
# Docker-based equivalent of generate_events.sh for Apple Silicon (ARM64).
# Uses linux/amd64 container to avoid JAXB/JNA incompatibility with Java 11.
#
# Generates multithreaded eventsim datasets for the configured date range.
# Each quarter runs in parallel as a separate eventsim process.
# Output: eventsim/output/YYYY_QN_control.json and YYYY_QN_test.json
#
# Usage:
#   bash generate_events_docker.sh
#   EVENTSIM_START=2025-01-01 EVENTSIM_END=2025-03-31 bash generate_events_docker.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — adjust as needed
# ---------------------------------------------------------------------------
CONFIG_DIR="$(cd "$(dirname "$0")/../config" && pwd)"
OUTPUT_DIR="$(cd "$(dirname "$0")/../output" && pwd)"

TOTAL_USERS=10000          # initial users per thread
GROWTH_RATE=0.30           # 30% user growth per period
CONTROL_SEED=1
TEST_SEED=2
# userid ranges must not overlap between threads
# Thread 1 (control): 1 – TOTAL_USERS
# Thread 2 (test):    TOTAL_USERS+1 – 2*TOTAL_USERS
CONTROL_START_USERID=1
TEST_START_USERID=$((TOTAL_USERS + 1))

START_DATE="${EVENTSIM_START:-2024-01-01}"
END_DATE="${EVENTSIM_END:-2024-03-31}"

LOG_FILE="${OUTPUT_DIR}/generate.log"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# Split date range into quarters: outputs "YYYY-MM-DD YYYY-MM-DD YYYY_QN" per line
generate_quarters() {
    local start="$1"
    local end="$2"

    python3 - <<PYEOF
from datetime import date
import calendar

def quarter_ranges(start: date, end: date):
    quarters = [(1,3), (4,6), (7,9), (10,12)]
    y = start.year
    while True:
        for q_num, (q_start_m, q_end_m) in enumerate(quarters, 1):
            qs = date(y, q_start_m, 1)
            last_day = calendar.monthrange(y, q_end_m)[1]
            qe = date(y, q_end_m, last_day)
            if qs > end:
                return
            actual_start = max(qs, start)
            actual_end   = min(qe, end)
            if actual_start <= actual_end:
                print(f"{actual_start} {actual_end} {y}_Q{q_num}")
        y += 1

quarter_ranges(
    date.fromisoformat("$start"),
    date.fromisoformat("$end")
)
PYEOF
}

run_eventsim() {
    local tag="$1"
    local start_time="$2"
    local end_time="$3"
    local start_userid="$4"
    local seed="$5"
    local label="$6"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting [$tag] $label | users=$TOTAL_USERS | $start_time → $end_time" | tee -a "$LOG_FILE"

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
            --start-time '${start_time}T00:00:00' \
            --end-time   '${end_time}T23:59:59' \
            --growth-rate ${GROWTH_RATE} \
            --userid ${start_userid} \
            --randomseed ${seed} \
            /output/${label}_${tag}.json
        " 2>&1 | tee -a "$LOG_FILE"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done    [$tag] $label → ${OUTPUT_DIR}/${label}_${tag}.json" | tee -a "$LOG_FILE"
}

# Heartbeat: prints running container names every 30s until signalled to stop
heartbeat() {
    while true; do
        sleep 30
        local running
        running=$(docker ps --filter ancestor=eventsim --format "{{.Names}}" 2>/dev/null | tr '\n' ' ')
        if [[ -n "$running" ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Still running: $running" | tee -a "$LOG_FILE"
        fi
    done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR"
log "=========================================="
log "Eventsim dataset generation (Docker)"
log "Period : $START_DATE → $END_DATE"
log "Users  : $TOTAL_USERS per thread (control + test)"
log "Output : $OUTPUT_DIR"
log "=========================================="

# Verify Docker image exists
if ! docker image inspect eventsim > /dev/null 2>&1; then
    log "ERROR: Docker image 'eventsim' not found."
    log "Build it first from the eventsim-repo directory:"
    log "  docker build --platform linux/amd64 -t eventsim eventsim-repo/"
    exit 1
fi

# Start heartbeat monitor in background
heartbeat &
HEARTBEAT_PID=$!

PIDS=()

while IFS=' ' read -r q_start q_end label; do
    # Run control and test threads in parallel for each quarter
    run_eventsim \
        "control" \
        "$q_start" "$q_end" \
        "$CONTROL_START_USERID" "$CONTROL_SEED" \
        "$label" &
    PIDS+=($!)

    run_eventsim \
        "test" \
        "$q_start" "$q_end" \
        "$TEST_START_USERID" "$TEST_SEED" \
        "$label" &
    PIDS+=($!)

done < <(generate_quarters "$START_DATE" "$END_DATE")

# Wait for all background jobs and collect exit codes
kill "$HEARTBEAT_PID" 2>/dev/null || true
FAILED=0
for pid in "${PIDS[@]}"; do
    if ! wait "$pid"; then
        log "WARNING: process $pid failed"
        FAILED=$((FAILED + 1))
    fi
done

if [[ $FAILED -eq 0 ]]; then
    log "All quarters completed successfully."
    log "Output files:"
    ls -lh "$OUTPUT_DIR"/*.json 2>/dev/null | tee -a "$LOG_FILE"
else
    log "ERROR: $FAILED process(es) failed. Check $LOG_FILE for details."
    exit 1
fi
