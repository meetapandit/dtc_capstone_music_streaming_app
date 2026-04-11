output "gke_cluster_name" {
  description = "GKE cluster name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE cluster endpoint (use with kubectl)"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_connect_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}

output "iceberg_bucket" {
  description = "GCS bucket for Apache Iceberg tables"
  value       = module.gcs.iceberg_bucket_url
}

output "raw_events_bucket" {
  description = "GCS bucket for raw event storage"
  value       = module.gcs.raw_events_bucket_url
}

output "dbt_artifacts_bucket" {
  description = "GCS bucket for dbt artifacts"
  value       = module.gcs.dbt_artifacts_bucket_url
}

output "flink_sa_email" {
  description = "Flink pipeline service account email (use for Workload Identity)"
  value       = module.iam.flink_sa_email
}

output "trino_sa_email" {
  description = "Trino service account email (use for Workload Identity)"
  value       = module.iam.trino_sa_email
}

output "airflow_sa_email" {
  description = "Airflow service account email (use for Workload Identity)"
  value       = module.iam.airflow_sa_email
}

output "clickhouse_sa_email" {
  description = "ClickHouse service account email (use for Workload Identity)"
  value       = module.iam.clickhouse_sa_email
}

output "bq_connection_name" {
  description = "Fully-qualified BigQuery connection name — paste into create_bronze_tables.sh or BigQuery SQL"
  value       = module.bigquery.connection_name
}

output "bq_connection_sa_email" {
  description = "Google-managed SA for the BigQuery connection — must have GCS access to the Iceberg bucket"
  value       = module.bigquery.connection_sa_email
}
