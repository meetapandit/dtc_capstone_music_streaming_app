# =============================================================================
# SERVICE ACCOUNTS
# One SA per service — principle of least privilege.
# All SAs use Workload Identity: no key files downloaded to disk.
# =============================================================================

# --- Flink Pipeline SA ---
# Needs: write Iceberg tables to GCS, read raw events bucket
resource "google_service_account" "flink" {
  account_id   = "flink-pipeline-sa"
  display_name = "Flink Pipeline Service Account"
  project      = var.project_id
}

# --- Trino SA ---
# Needs: read Iceberg tables from GCS, read dbt artifacts
resource "google_service_account" "trino" {
  account_id   = "trino-sa"
  display_name = "Trino Query Engine Service Account"
  project      = var.project_id
}

# --- ClickHouse SA ---
# Needs: read Iceberg tables from GCS (external table access)
resource "google_service_account" "clickhouse" {
  account_id   = "clickhouse-sa"
  display_name = "ClickHouse Service Account"
  project      = var.project_id
}

# --- Airflow SA ---
# Needs: read/write GCS (dbt artifacts, logs), trigger GKE jobs via K8s API
resource "google_service_account" "airflow" {
  account_id   = "airflow-sa"
  display_name = "Airflow Orchestration Service Account"
  project      = var.project_id
}

# =============================================================================
# GCS BUCKET-LEVEL IAM BINDINGS (preferred over project-level roles)
# =============================================================================

# Flink: full read/write on iceberg bucket (creates tables, writes data+metadata)
resource "google_storage_bucket_iam_member" "flink_iceberg_rw" {
  bucket = var.iceberg_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.flink.email}"
}

resource "google_storage_bucket_iam_member" "flink_iceberg_bucket_reader" {
  bucket = var.iceberg_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.flink.email}"
}

# Flink: write raw events backup
resource "google_storage_bucket_iam_member" "flink_raw_events_rw" {
  bucket = var.raw_events_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.flink.email}"
}

resource "google_storage_bucket_iam_member" "flink_raw_events_bucket_reader" {
  bucket = var.raw_events_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.flink.email}"
}

# Trino: read-only on iceberg bucket
resource "google_storage_bucket_iam_member" "trino_iceberg_ro" {
  bucket = var.iceberg_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.trino.email}"
}

resource "google_storage_bucket_iam_member" "trino_iceberg_bucket_reader" {
  bucket = var.iceberg_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.trino.email}"
}

# Trino: read dbt artifacts
resource "google_storage_bucket_iam_member" "trino_dbt_ro" {
  bucket = var.dbt_artifacts_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.trino.email}"
}

resource "google_storage_bucket_iam_member" "trino_dbt_bucket_reader" {
  bucket = var.dbt_artifacts_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.trino.email}"
}

# ClickHouse: read-only on iceberg bucket
resource "google_storage_bucket_iam_member" "clickhouse_iceberg_ro" {
  bucket = var.iceberg_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.clickhouse.email}"
}

resource "google_storage_bucket_iam_member" "clickhouse_iceberg_bucket_reader" {
  bucket = var.iceberg_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.clickhouse.email}"
}

# Airflow: read/write dbt artifacts (uploads compiled manifests)
resource "google_storage_bucket_iam_member" "airflow_dbt_rw" {
  bucket = var.dbt_artifacts_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.airflow.email}"
}

resource "google_storage_bucket_iam_member" "airflow_dbt_bucket_reader" {
  bucket = var.dbt_artifacts_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.airflow.email}"
}

# Airflow: read raw events (for data quality checks)
resource "google_storage_bucket_iam_member" "airflow_raw_ro" {
  bucket = var.raw_events_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.airflow.email}"
}

resource "google_storage_bucket_iam_member" "airflow_raw_bucket_reader" {
  bucket = var.raw_events_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.airflow.email}"
}

# =============================================================================
# WORKLOAD IDENTITY BINDINGS
# Maps K8s service accounts → GCP service accounts.
# Format: "serviceAccount:{project}.svc.id.goog[{namespace}/{ksa-name}]"
#
# Each K8s SA (in its namespace) is allowed to impersonate the GCP SA.
# You must also annotate the K8s SA with:
#   iam.gke.io/gcp-service-account: <gcp-sa-email>
# =============================================================================

resource "google_service_account_iam_member" "flink_workload_identity" {
  service_account_id = google_service_account.flink.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[flink/flink-sa]"
}

resource "google_service_account_iam_member" "trino_workload_identity" {
  service_account_id = google_service_account.trino.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[trino/trino-sa]"
}

resource "google_service_account_iam_member" "clickhouse_workload_identity" {
  service_account_id = google_service_account.clickhouse.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[clickhouse/clickhouse-sa]"
}

resource "google_service_account_iam_member" "airflow_workload_identity" {
  service_account_id = google_service_account.airflow.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[airflow/airflow-sa]"
}
