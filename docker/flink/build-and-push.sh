#!/usr/bin/env bash
# Builds the custom Flink image and pushes to Google Artifact Registry
set -euo pipefail

PROJECT_ID="dtc-capstone-491118"
REGION="us-west1"
IMAGE="us-west1-docker.pkg.dev/${PROJECT_ID}/music-streaming/flink-iceberg:1.18.1"

echo "Configuring Docker auth for GCR..."
gcloud auth configure-docker us-west1-docker.pkg.dev --quiet

echo "Creating Artifact Registry repo (if not exists)..."
gcloud artifacts repositories create music-streaming \
  --repository-format=docker \
  --location=${REGION} \
  --project=${PROJECT_ID} 2>/dev/null || true

echo "Building image for linux/amd64 (required for GKE)..."
docker buildx build --platform linux/amd64 -t "${IMAGE}" --push "$(dirname "$0")"

echo ""
echo "Done! Image: ${IMAGE}"
echo "Update flink-session-cluster.yaml image to: ${IMAGE}"
