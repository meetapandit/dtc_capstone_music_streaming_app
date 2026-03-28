output "flink_sa_email" {
  value = google_service_account.flink.email
}

output "trino_sa_email" {
  value = google_service_account.trino.email
}

output "clickhouse_sa_email" {
  value = google_service_account.clickhouse.email
}

output "airflow_sa_email" {
  value = google_service_account.airflow.email
}
