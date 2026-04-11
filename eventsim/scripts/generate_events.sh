#!/usr/bin/env bash
# =============================================================================
# generate_events.sh
# Generates multithreaded eventsim datasets from 2024-01-01 to today.
# Each quarter runs in parallel as a separate eventsim process.
# Output: eventsim/output/YYYY_QN.json (one file per quarter per tag)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — adjust as needed
# ---------------------------------------------------------------------------
EVENTSIM_HOME="${EVENTSIM_HOME:-$(pwd)/eventsim-repo}"   # path to cloned eventsim repo
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

# Split date range into quarters: outputs pairs of "YYYY-MM-DD YYYY-MM-DD LABEL"
generate_quarters() {
    local start="$1"
    local end="$2"

    python3 - <<PYEOF
from datetime import date, timedelta
import sys

def quarter_ranges(start: date, end: date):
    quarters = [(1,3), (4,6), (7,9), (10,12)]
    y = start.year
    while True:
        for q_num, (q_start_m, q_end_m) in enumerate(quarters, 1):
            import calendar
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
    local config="$2"
    local start_time="$3"
    local end_time="$4"
    local start_userid="$5"
    local seed="$6"
    local label="$7"
    local outfile="${OUTPUT_DIR}/${label}_${tag}.json"

    log "Starting [$tag] $label | users=$TOTAL_USERS | $start_time → $end_time"

    (cd "${EVENTSIM_HOME}" && ./bin/eventsim \
        --config "$config" \
        --tag "$tag" \
        -n "$TOTAL_USERS" \
        --start-time "${start_time}T00:00:00" \
        --end-time   "${end_time}T23:59:59" \
        --growth-rate "$GROWTH_RATE" \
        --userid "$start_userid" \
        --randomseed "$seed" \
        "$outfile") >> "$LOG_FILE" 2>&1

    log "Done    [$tag] $label → $outfile"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR"
log "=========================================="
log "Eventsim dataset generation"
log "Period : $START_DATE → $END_DATE"
log "Users  : $TOTAL_USERS per thread (control + test)"
log "Output : $OUTPUT_DIR"
log "=========================================="

# Check eventsim binary exists
if [[ ! -x "${EVENTSIM_HOME}/bin/eventsim" ]]; then
    log "ERROR: eventsim binary not found at ${EVENTSIM_HOME}/bin/eventsim"
    log "Clone and build it first:"
    log "  git clone https://github.com/viirya/eventsim ${EVENTSIM_HOME}"
    log "  cd ${EVENTSIM_HOME} && sbt assembly"
    exit 1
fi

PIDS=()

while IFS=' ' read -r q_start q_end label; do
    # Run control and test threads in parallel for each quarter
    run_eventsim \
        "control" \
        "${CONFIG_DIR}/control-config.json" \
        "$q_start" "$q_end" \
        "$CONTROL_START_USERID" "$CONTROL_SEED" \
        "$label" &
    PIDS+=($!)

    run_eventsim \
        "test" \
        "${CONFIG_DIR}/test-config.json" \
        "$q_start" "$q_end" \
        "$TEST_START_USERID" "$TEST_SEED" \
        "$label" &
    PIDS+=($!)

done < <(generate_quarters "$START_DATE" "$END_DATE")

# Wait for all background jobs and collect exit codes
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
