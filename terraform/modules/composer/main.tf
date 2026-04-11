# =============================================================================
# Cloud Composer 3 (managed Airflow)
# Composer 3 is fully managed — no visible GKE nodes, no node_config, no
# environment_size. Google manages the underlying infrastructure.
# Workloads are sized via workloads_config only.
# =============================================================================

resource "google_composer_environment" "airflow" {
  name    = "${var.environment}-music-streaming-airflow"
  region  = var.region
  project = var.project_id

  config {
    node_config {
      service_account = var.airflow_sa_email
    }

    software_config {
      image_version = "composer-3-airflow-2.10.5"

      pypi_packages = {
        "dbt-core"     = ">=1.8"
        "dbt-bigquery" = ">=1.8"
      }

      env_variables = {
        DBT_PROJECT_DIR  = "/home/airflow/gcs/dags/dbt"
        DBT_PROFILES_DIR = "/home/airflow/gcs/dags/dbt"
      }
    }

    workloads_config {
      scheduler {
        cpu        = 0.5
        memory_gb  = 2.0
        storage_gb = 1
        count      = 1
      }
      web_server {
        cpu        = 0.5
        memory_gb  = 2.0
        storage_gb = 1
      }
      worker {
        cpu        = 0.5
        memory_gb  = 2.0
        storage_gb = 1
        min_count  = 1
        max_count  = 3
      }
    }
  }
}
