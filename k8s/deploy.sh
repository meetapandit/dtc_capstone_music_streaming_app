#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Deploy Kafka (Strimzi) + Flink to GKE
# Run this after terraform apply has provisioned the GKE cluster
# =============================================================================

set -euo pipefail

PROJECT_ID="${PROJECT_ID:-dtc-capstone-491118}"
REGION="${REGION:-us-west1-b}"
CLUSTER_NAME="${CLUSTER_NAME:-dev-music-streaming-cluster}"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---------------------------------------------------------------------------
# 0. Connect kubectl to GKE cluster
# ---------------------------------------------------------------------------
log "Connecting kubectl to GKE cluster..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --region "$REGION" \
  --project "$PROJECT_ID"

kubectl cluster-info

# ---------------------------------------------------------------------------
# 1. Create namespaces
# ---------------------------------------------------------------------------
log "Creating namespaces..."
kubectl apply -f namespaces/namespaces.yaml

# ---------------------------------------------------------------------------
# 2. Install Strimzi Operator (Kafka)
# ---------------------------------------------------------------------------
log "Installing Strimzi operator..."
STRIMZI_VERSION="0.41.0"

kubectl create -f "https://strimzi.io/install/latest?namespace=kafka" \
  --namespace kafka 2>/dev/null || log "Strimzi CRDs already installed, skipping."

log "Waiting for Strimzi operator to be ready..."
kubectl rollout status deployment/strimzi-cluster-operator -n kafka --timeout=120s

# ---------------------------------------------------------------------------
# 3. Deploy Kafka Cluster + Topics
# ---------------------------------------------------------------------------
log "Deploying Kafka cluster..."
kubectl apply -f kafka/kafka-cluster.yaml

log "Waiting for Kafka cluster to be ready (this takes ~3-5 min)..."
kubectl wait kafka/music-streaming-kafka \
  --for=condition=Ready \
  --timeout=300s \
  -n kafka

log "Creating Kafka topics..."
kubectl apply -f kafka/kafka-topics.yaml

# ---------------------------------------------------------------------------
# 4. Install Flink Kubernetes Operator
# ---------------------------------------------------------------------------
log "Installing Flink Kubernetes Operator..."

# Install cert-manager (required by Flink operator webhook)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.5/cert-manager.yaml
log "Waiting for cert-manager..."
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=120s

helm repo add flink-operator-repo \
  https://downloads.apache.org/flink/flink-kubernetes-operator-1.12.1/
helm repo update flink-operator-repo

helm upgrade --install flink-kubernetes-operator \
  flink-operator-repo/flink-kubernetes-operator \
  --namespace flink \
  --create-namespace \
  -f flink/flink-operator-values.yaml \
  --wait

# ---------------------------------------------------------------------------
# 5. Deploy Flink Service Account + RBAC
# ---------------------------------------------------------------------------
log "Deploying Flink service account..."
kubectl apply -f flink/flink-serviceaccount.yaml

# ---------------------------------------------------------------------------
# 6. Deploy Flink Session Cluster
# ---------------------------------------------------------------------------
log "Deploying Flink session cluster..."
kubectl apply -f flink/flink-session-cluster.yaml

log "Waiting for Flink JobManager to be ready..."
kubectl rollout status deployment/music-streaming-flink -n flink --timeout=180s 2>/dev/null || \
  kubectl wait flinkdeployment/music-streaming-flink \
    --for=condition=Available \
    --timeout=180s \
    -n flink 2>/dev/null || true

# ---------------------------------------------------------------------------
# 7. Print connection info
# ---------------------------------------------------------------------------
log ""
log "=========================================="
log "Deployment complete!"
log "=========================================="
log ""
log "Kafka bootstrap (internal, for Flink/apps in GKE):"
log "  music-streaming-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092"
log ""
log "Kafka bootstrap (external, for eventsim on your laptop):"
EXTERNAL_IP=$(kubectl get svc music-streaming-kafka-kafka-external-bootstrap \
  -n kafka -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "<pending>")
log "  ${EXTERNAL_IP}:9094"
log ""
log "Flink Web UI (port-forward to access):"
log "  kubectl port-forward svc/music-streaming-flink-rest 8081:8081 -n flink"
log "  Then open: http://localhost:8081"
log ""
log "Update eventsim stream_to_kafka.py --broker to: ${EXTERNAL_IP}:9094"
