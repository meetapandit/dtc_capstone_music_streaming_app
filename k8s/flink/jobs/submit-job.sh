#!/usr/bin/env bash
# =============================================================================
# submit-job.sh
# Copies the SQL file into the JobManager pod and runs it with the built-in
# Flink SQL Client (bin/sql-client.sh -f).  No SQL Gateway or Python needed.
#
# Run from: k8s/flink/jobs/
# Prerequisites: kubectl
# =============================================================================

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SQL_FILE="$DIR/kafka-to-iceberg.sql"
NAMESPACE="flink"

# ---------------------------------------------------------------------------
# 1. Find the running JobManager pod
# ---------------------------------------------------------------------------
echo "==> Locating JobManager pod..."
FLINK_POD=$(kubectl get pods -n "$NAMESPACE" -l component=jobmanager \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}')

if [[ -z "$FLINK_POD" ]]; then
  echo "ERROR: No running JobManager pod found in namespace '$NAMESPACE'." >&2
  exit 1
fi
echo "    pod: $FLINK_POD"

# ---------------------------------------------------------------------------
# 2. Copy the SQL file into the pod
# ---------------------------------------------------------------------------
echo "==> Copying SQL file to pod..."
kubectl cp "$SQL_FILE" "$NAMESPACE/$FLINK_POD:/tmp/kafka-to-iceberg.sql"

# ---------------------------------------------------------------------------
# 3. Submit via the built-in SQL Client (no Gateway, no Python required)
# ---------------------------------------------------------------------------
echo "==> Submitting SQL via sql-client.sh -f ..."
echo ""
kubectl exec -n "$NAMESPACE" "$FLINK_POD" -- \
  /opt/flink/bin/sql-client.sh -f /tmp/kafka-to-iceberg.sql

echo ""
echo "==> Monitor running jobs:"
echo "    kubectl port-forward svc/music-streaming-flink-rest 8081:8081 -n flink"
echo "    http://localhost:8081"
