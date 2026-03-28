variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for zonal resources"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# --- GKE ---

variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "music-streaming-cluster"
}

variable "gke_master_version" {
  description = "Kubernetes version for the GKE control plane"
  type        = string
  default     = "latest"
}

variable "general_node_count" {
  description = "Number of nodes in the general-purpose node pool"
  type        = number
  default     = 2
}

variable "general_machine_type" {
  description = "Machine type for general-purpose nodes (Airflow, Superset, eventsim)"
  type        = string
  default     = "e2-standard-4" # 4 vCPU, 16 GB
}

variable "data_node_count" {
  description = "Number of nodes in the data services node pool"
  type        = number
  default     = 3
}

variable "data_machine_type" {
  description = "Machine type for data service nodes (Kafka, Flink, ClickHouse, Trino)"
  type        = string
  default     = "e2-standard-8" # 8 vCPU, 32 GB
}

# --- GCS ---

variable "iceberg_bucket_name" {
  description = "GCS bucket name for Apache Iceberg tables"
  type        = string
}

variable "raw_events_bucket_name" {
  description = "GCS bucket name for raw event backups and replay"
  type        = string
}

variable "dbt_artifacts_bucket_name" {
  description = "GCS bucket name for dbt compilation artifacts and docs"
  type        = string
}

variable "gcs_location" {
  description = "GCS bucket location"
  type        = string
  default     = "US"
}
