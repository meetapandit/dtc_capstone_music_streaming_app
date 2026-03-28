output "iceberg_bucket_url" {
  value = "gs://${google_storage_bucket.iceberg.name}"
}

output "iceberg_bucket_name" {
  value = google_storage_bucket.iceberg.name
}

output "raw_events_bucket_url" {
  value = "gs://${google_storage_bucket.raw_events.name}"
}

output "dbt_artifacts_bucket_url" {
  value = "gs://${google_storage_bucket.dbt_artifacts.name}"
}
