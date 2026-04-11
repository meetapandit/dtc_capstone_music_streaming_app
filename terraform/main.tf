# Resolve project number dynamically — used for service agent SA emails
data "google_project" "project" {
  project_id = var.project_id
}

# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",           # GKE
    "storage.googleapis.com",             # GCS
    "iam.googleapis.com",                 # IAM
    "compute.googleapis.com",             # VPC / Compute
    "cloudresourcemanager.googleapis.com",
    "composer.googleapis.com",            # Cloud Composer (Airflow)
    "bigquery.googleapis.com",            # BigQuery (dbt target)
    "bigqueryconnection.googleapis.com",  # BigLake Cloud Resource Connections
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# --- VPC ---
module "vpc" {
  source = "./modules/vpc"

  project_id  = var.project_id
  region      = var.region
  environment = var.environment

  depends_on = [google_project_service.apis]
}

# --- IAM: Service Accounts ---
module "iam" {
  source = "./modules/iam"

  project_id     = var.project_id
  project_number = data.google_project.project.number

  iceberg_bucket_name       = var.iceberg_bucket_name
  raw_events_bucket_name    = var.raw_events_bucket_name
  dbt_artifacts_bucket_name = var.dbt_artifacts_bucket_name

  depends_on = [google_project_service.apis]
}

# --- BigQuery Connection (BigLake Iceberg) ---
module "bigquery" {
  source = "./modules/bigquery"

  project_id          = var.project_id
  region              = var.region
  connection_id       = var.bq_connection_id
  iceberg_bucket_name = var.iceberg_bucket_name

  depends_on = [google_project_service.apis, module.gcs]
}

# --- GCS Buckets ---
module "gcs" {
  source = "./modules/gcs"

  project_id                = var.project_id
  gcs_location              = var.gcs_location
  environment               = var.environment
  iceberg_bucket_name       = var.iceberg_bucket_name
  raw_events_bucket_name    = var.raw_events_bucket_name
  dbt_artifacts_bucket_name = var.dbt_artifacts_bucket_name

  depends_on = [google_project_service.apis]
}

# --- Cloud Composer 2 (Airflow) ---
module "composer" {
  source = "./modules/composer"

  project_id       = var.project_id
  region           = var.region
  environment      = var.environment
  airflow_sa_email = module.iam.airflow_sa_email

  depends_on = [module.iam, google_project_service.apis]
}

# --- GKE Cluster ---
module "gke" {
  source = "./modules/gke"

  project_id           = var.project_id
  region               = var.region
  zone                 = var.zone
  environment          = var.environment
  cluster_name         = var.gke_cluster_name
  master_version       = var.gke_master_version
  network              = module.vpc.network_name
  subnetwork           = module.vpc.subnet_name
  pods_range_name      = module.vpc.pods_range_name
  services_range_name  = module.vpc.services_range_name
  general_node_count   = var.general_node_count
  general_machine_type = var.general_machine_type
  data_node_count      = var.data_node_count
  data_machine_type    = var.data_machine_type
  data_disk_size_gb    = var.data_disk_size_gb
  data_disk_type       = var.data_disk_type

  depends_on = [module.vpc]
}
