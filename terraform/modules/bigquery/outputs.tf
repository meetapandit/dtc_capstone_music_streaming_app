output "connection_id" {
  description = "Short connection ID"
  value       = google_bigquery_connection.iceberg.connection_id
}

output "connection_name" {
  description = "Fully-qualified connection reference used in BigQuery SQL: PROJECT.REGION.CONNECTION_ID"
  value       = "${var.project_id}.${var.region}.${google_bigquery_connection.iceberg.connection_id}"
}

output "connection_sa_email" {
  description = "Email of the Google-managed SA provisioned for the connection"
  value       = google_bigquery_connection.iceberg.cloud_resource[0].service_account_id
}
