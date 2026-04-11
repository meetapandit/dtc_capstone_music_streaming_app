# --- Iceberg Tables Bucket ---
# Primary storage for all Iceberg tables (Flink writes, Trino + ClickHouse read)
resource "google_storage_bucket" "iceberg" {
  name          = var.iceberg_bucket_name
  project       = var.project_id
  location      = var.gcs_location
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  versioning {
    enabled = false # Iceberg manages its own snapshots
  }

  lifecycle_rule {
    condition {
      age = 90 # move old Iceberg metadata/data files after 90 days
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  labels = {
    env     = var.environment
    purpose = "iceberg-storage"
  }
}

# Folder structure (created via empty objects)
resource "google_storage_bucket_object" "iceberg_folders" {
  for_each = toset([
    "warehouse/listen_events/.keep",
    "warehouse/auth_events/.keep",
    "warehouse/page_events/.keep",
    "warehouse/enriched_sessions/.keep",
    "warehouse/trending_songs/.keep",
  ])

  name    = each.value
  bucket  = google_storage_bucket.iceberg.name
  content = " "
}

# --- Raw Events Bucket ---
# Kafka → GCS sink for raw event replay and backup
resource "google_storage_bucket" "raw_events" {
  name          = var.raw_events_bucket_name
  project       = var.project_id
  location      = var.gcs_location
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    env     = var.environment
    purpose = "raw-events-backup"
  }
}

# --- dbt Artifacts Bucket ---
# Stores compiled dbt manifests, docs, and run results
resource "google_storage_bucket" "dbt_artifacts" {
  name          = var.dbt_artifacts_bucket_name
  project       = var.project_id
  location      = var.gcs_location
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  labels = {
    env     = var.environment
    purpose = "dbt-artifacts"
  }
}
