output "airflow_uri" {
  description = "URL of the Airflow web UI."
  value       = google_composer_environment.airflow.config[0].airflow_uri
}

output "gcs_bucket" {
  description = "GCS bucket backing this Composer environment (DAGs live in /dags)."
  value       = google_composer_environment.airflow.config[0].dag_gcs_prefix
}
