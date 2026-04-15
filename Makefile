# =============================================================================
# Makefile — BeatStream Analytics Pipeline
# GCP Data Engineering Capstone
#
# Usage:
#   make help          — show all targets
#   make all           — full cold-start (terraform → gke → flink → dbt → dags)
#   make <target>      — run a specific target
#
# Override any variable at call time:
#   make tf-apply PROJECT_ID=my-other-project
# =============================================================================

# -----------------------------------------------------------------------------
# Project-level variables
# -----------------------------------------------------------------------------
PROJECT_ID   ?= dtc-capstone-491118
REGION       ?= us-west1
ZONE         ?= us-west1-b
CLUSTER_NAME ?= dev-music-streaming-cluster
DBT_DIR      ?= dbt
DAGS_BUCKET  ?= gs://us-west1-dev-music-streamin-713dfd5d-bucket/dags

REPO_ROOT    := $(shell pwd)
TF_DIR       := $(REPO_ROOT)/terraform
K8S_DIR      := $(REPO_ROOT)/k8s
EVENTSIM_DIR := $(REPO_ROOT)/eventsim

# Python interpreter — override with: make stream PYTHON=python3.11
PYTHON ?= python3

# Speed multiplier passed to stream_to_kafka.py (0 = as fast as possible)
STREAM_SPEED ?= 0

# -----------------------------------------------------------------------------
# Default target
# -----------------------------------------------------------------------------
.DEFAULT_GOAL := help

# =============================================================================
##@ General
# =============================================================================

.PHONY: help
help: ## Show this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} \
	     /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-26s\033[0m %s\n", $$1, $$2 } \
	     /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) }' \
	     $(MAKEFILE_LIST)

.PHONY: all
all: tf-init tf-apply gke-connect gke-deploy flink-submit dbt-run composer-deploy ## Full cold-start: terraform → gke → flink → dbt → dags
	@echo ""
	@echo "=============================================="
	@echo "  Pipeline fully deployed."
	@echo "  Run 'make dbt-test' to validate transforms."
	@echo "=============================================="

# =============================================================================
##@ Infrastructure (Terraform)
# =============================================================================

.PHONY: tf-init
tf-init: ## terraform init — download providers and modules
	@echo "==> [terraform] Initialising working directory..."
	terraform -chdir=$(TF_DIR) init

.PHONY: tf-plan
tf-plan: ## terraform plan — preview changes (saves plan to terraform/tfplan)
	@echo "==> [terraform] Planning changes..."
	terraform -chdir=$(TF_DIR) plan \
	  -var="project_id=$(PROJECT_ID)" \
	  -var="region=$(REGION)" \
	  -var="zone=$(ZONE)" \
	  -out=tfplan

.PHONY: tf-apply
tf-apply: ## terraform apply — provision all GCP infrastructure
	@echo "==> [terraform] Applying infrastructure..."
	@echo "    project : $(PROJECT_ID)"
	@echo "    region  : $(REGION)"
	@echo "    zone    : $(ZONE)"
	terraform -chdir=$(TF_DIR) apply \
	  -var="project_id=$(PROJECT_ID)" \
	  -var="region=$(REGION)" \
	  -var="zone=$(ZONE)" \
	  -auto-approve

.PHONY: tf-destroy
tf-destroy: ## terraform destroy — tear down ALL GCP resources (irreversible)
	@echo "==> [terraform] Destroying infrastructure..."
	@echo "    WARNING: This will delete all GCP resources."
	@read -p "    Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || (echo "Aborted." && exit 1)
	terraform -chdir=$(TF_DIR) destroy \
	  -var="project_id=$(PROJECT_ID)" \
	  -var="region=$(REGION)" \
	  -var="zone=$(ZONE)" \
	  -auto-approve

.PHONY: tf-output
tf-output: ## terraform output — print all output values
	@echo "==> [terraform] Outputs:"
	terraform -chdir=$(TF_DIR) output

# =============================================================================
##@ GKE — Kubernetes Cluster
# =============================================================================

.PHONY: gke-connect
gke-connect: ## Configure kubectl to connect to the GKE cluster
	@echo "==> [gke] Connecting kubectl to cluster '$(CLUSTER_NAME)'..."
	gcloud container clusters get-credentials $(CLUSTER_NAME) \
	  --zone $(ZONE) \
	  --project $(PROJECT_ID)
	@echo "==> [gke] Cluster info:"
	kubectl cluster-info

.PHONY: gke-deploy
gke-deploy: ## Deploy Strimzi Kafka + Flink operator to GKE (runs k8s/deploy.sh)
	@echo "==> [gke] Deploying Kafka (Strimzi) + Flink operator to GKE..."
	@echo "    This step takes approximately 5-10 minutes."
	cd $(K8S_DIR) && bash deploy.sh

.PHONY: flink-deploy-cluster
flink-deploy-cluster: ## Deploy the Flink session cluster (JobManager + TaskManager)
	@echo "==> [flink] Deploying Flink session cluster..."
	kubectl apply -f $(K8S_DIR)/flink/flink-session-cluster.yaml
	@echo "==> [flink] Waiting for JobManager pod... (watch with: make gke-status)"

.PHONY: flink-submit
flink-submit: ## Submit the Flink SQL job (kafka-to-iceberg) to the session cluster
	@echo "==> [flink] Submitting Flink SQL job..."
	cd $(K8S_DIR)/flink/jobs && bash submit-job.sh
	@echo "==> [flink] Job submitted. Monitor at:"
	@echo "    make flink-ui"

.PHONY: gke-status
gke-status: ## Show pod status across kafka and flink namespaces
	@echo "==> [gke] Pod status — namespace: kafka"
	kubectl get pods -n kafka -o wide
	@echo ""
	@echo "==> [gke] Pod status — namespace: flink"
	kubectl get pods -n flink -o wide
	@echo ""
	@echo "==> [gke] Services with external IPs — namespace: kafka"
	kubectl get svc -n kafka | grep -E 'NAME|LoadBalancer'

.PHONY: flink-ui
flink-ui: ## Port-forward the Flink Web UI to localhost:8081
	@echo "==> [flink] Forwarding Flink REST UI → http://localhost:8081"
	@echo "    Press Ctrl+C to stop."
	kubectl port-forward svc/music-streaming-flink-rest 8081:8081 -n flink

# =============================================================================
##@ Eventsim — Data Generation
# =============================================================================

# Date range for event generation — override at call time:
#   make eventsim-generate EVENTSIM_START=2024-01-01 EVENTSIM_END=2024-03-31
EVENTSIM_START ?= 2025-01-01
EVENTSIM_END   ?= 2025-03-31

.PHONY: eventsim-build
eventsim-build: ## Build the eventsim Docker image (run once after git submodule update --init)
	@echo "==> [eventsim] Building Docker image (linux/amd64)..."
	@echo "    This may take 5-10 minutes on first build."
	cd $(REPO_ROOT)/eventsim-repo && \
	  docker build --platform linux/amd64 -t eventsim -f docker/Dockerfile .
	@echo "==> [eventsim] Image 'eventsim' built successfully."

.PHONY: eventsim-generate
eventsim-generate: ## Generate eventsim event files (set EVENTSIM_START and EVENTSIM_END)
	@echo "==> [eventsim] Generating events: $(EVENTSIM_START) → $(EVENTSIM_END)"
	@echo "    Output: $(EVENTSIM_DIR)/output/"
	EVENTSIM_START=$(EVENTSIM_START) EVENTSIM_END=$(EVENTSIM_END) \
	  bash $(EVENTSIM_DIR)/scripts/generate_events_docker.sh
	@echo "==> [eventsim] Done. Files written to $(EVENTSIM_DIR)/output/"

# =============================================================================
##@ Streaming — Eventsim Producer
# =============================================================================

.PHONY: stream
stream: ## Stream eventsim events to Kafka (requires BROKER=<ip>:9094)
ifndef BROKER
	$(error BROKER is not set. Usage: make stream BROKER=<external-ip>:9094)
endif
	@echo "==> [eventsim] Streaming events to Kafka broker $(BROKER)..."
	@echo "    Speed multiplier: $(STREAM_SPEED)x  (0 = unlimited)"
	$(PYTHON) $(EVENTSIM_DIR)/scripts/stream_to_kafka.py \
	  --output-dir $(EVENTSIM_DIR)/output \
	  --broker $(BROKER) \
	  --speed-multiplier $(STREAM_SPEED)

.PHONY: kafka-external-ip
kafka-external-ip: ## Print the external LoadBalancer IP for the Kafka bootstrap service
	@echo "==> [kafka] External bootstrap IP:"
	kubectl get svc music-streaming-kafka-kafka-external-bootstrap \
	  -n kafka \
	  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
	@echo ""
	@echo "    Use with: make stream BROKER=<ip>:9094"

# =============================================================================
##@ BigQuery — Bronze Tables Setup
# =============================================================================

.PHONY: bronze-tables
bronze-tables: ## Create BigLake Iceberg external tables in BigQuery bronze dataset
	@echo "==> [bigquery] Creating bronze BigLake external tables..."
	@echo "    Run this after Flink has written data to GCS."
	bash $(REPO_ROOT)/dbt/setup/create_bronze_tables.sh

# =============================================================================
##@ dbt — Data Transformations
# =============================================================================

.PHONY: dbt-setup
dbt-setup: ## Copy dbt/profiles.yml to ~/.dbt/profiles.yml (run once before first dbt-run)
	@echo "==> [dbt] Installing profiles.yml to ~/.dbt/profiles.yml..."
	mkdir -p ~/.dbt
	cp $(REPO_ROOT)/$(DBT_DIR)/profiles.yml ~/.dbt/profiles.yml
	@echo "==> [dbt] Done. Edit ~/.dbt/profiles.yml if you need to change project/dataset settings."

.PHONY: dbt-run
dbt-run: ## dbt run — build all silver + gold models (incremental)
	@echo "==> [dbt] Running all models..."
	cd $(REPO_ROOT)/$(DBT_DIR) && dbt run

.PHONY: dbt-test
dbt-test: ## dbt test — run all schema and data quality tests
	@echo "==> [dbt] Running tests..."
	cd $(REPO_ROOT)/$(DBT_DIR) && dbt test

.PHONY: dbt-full-refresh
dbt-full-refresh: ## dbt run --full-refresh — rebuild all tables from scratch (use after schema changes or cold start)
	@echo "==> [dbt] Full refresh — rebuilding all models from scratch..."
	@echo "    WARNING: This will truncate and reload all silver and gold tables."
	@echo "    When to use:"
	@echo "      - After a cold start (new GCS data, new bronze tables)"
	@echo "      - After schema changes to silver or gold models"
	@echo "      - After dbt model logic changes that affect historical rows"
	@echo "      - NOT needed for routine incremental runs (use make dbt-run instead)"
	@read -p "    Proceed with full refresh? [y/N]: " confirm && \
	  { [ "$$confirm" = "y" ] && cd $(REPO_ROOT)/$(DBT_DIR) && dbt run --full-refresh; } || \
	  echo "Aborted."

.PHONY: dbt-silver
dbt-silver: ## dbt run — silver layer only (raw → cleaned/typed events)
	@echo "==> [dbt] Running silver models only..."
	cd $(REPO_ROOT)/$(DBT_DIR) && dbt run --select silver

.PHONY: dbt-gold
dbt-gold: ## dbt run — gold layer only (aggregates, KPIs, dashboards)
	@echo "==> [dbt] Running gold models only..."
	cd $(REPO_ROOT)/$(DBT_DIR) && dbt run --select gold

.PHONY: dbt-docs
dbt-docs: ## Generate and serve dbt docs at localhost:8080
	@echo "==> [dbt] Generating documentation..."
	cd $(REPO_ROOT)/$(DBT_DIR) && dbt docs generate
	@echo "==> [dbt] Serving docs at http://localhost:8080 — press Ctrl+C to stop."
	cd $(REPO_ROOT)/$(DBT_DIR) && dbt docs serve --port 8080

# =============================================================================
##@ Composer / Airflow — DAG Deployment
# =============================================================================

.PHONY: composer-deploy
composer-deploy: ## Upload dbt project + DAG file to the Composer GCS bucket
	@echo "==> [composer] Deploying DAGs and dbt project to Composer..."
	@echo "    Target bucket: $(DAGS_BUCKET)"
	cd $(REPO_ROOT) && bash dags/deploy_dags.sh
	@echo "==> [composer] Done. DAG will appear in Airflow within ~1 minute."

.PHONY: composer-list-dags
composer-list-dags: ## List DAGs currently loaded in the Composer Airflow environment
	@echo "==> [composer] Listing DAGs in Airflow..."
	gcloud composer environments run dev-music-streaming-airflow \
	  --location $(REGION) \
	  dags list

.PHONY: composer-trigger
composer-trigger: ## Manually trigger the music_streaming_dbt_wap DAG
	@echo "==> [composer] Triggering DAG: music_streaming_dbt_wap..."
	gcloud composer environments run dev-music-streaming-airflow \
	  --location $(REGION) \
	  dags trigger -- music_streaming_dbt_wap
