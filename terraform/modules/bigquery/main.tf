# =============================================================================
# BigQuery Cloud Resource Connection for BigLake Iceberg tables
#
# A Cloud Resource Connection provisions a Google-managed service account
# that BigQuery uses to access GCS when reading/writing Iceberg data and
# metadata files.  Without it, BigQuery can only read (no DML).
# =============================================================================

resource "google_bigquery_connection" "iceberg" {
  connection_id = var.connection_id
  project       = var.project_id
  location      = var.region

  cloud_resource {}
}

# ---------------------------------------------------------------------------
# Grant the connection's auto-provisioned SA access to the Iceberg bucket.
#
# objectAdmin  → read data + metadata files (queries) AND write new
#                data/metadata files (INSERT / UPDATE / DELETE / MERGE)
# legacyBucketReader → list bucket contents (required alongside objectAdmin)
# ---------------------------------------------------------------------------

resource "google_storage_bucket_iam_member" "bq_connection_iceberg_rw" {
  bucket = var.iceberg_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_bigquery_connection.iceberg.cloud_resource[0].service_account_id}"
}

resource "google_storage_bucket_iam_member" "bq_connection_iceberg_bucket_reader" {
  bucket = var.iceberg_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_bigquery_connection.iceberg.cloud_resource[0].service_account_id}"
}
