# Enable required GCP APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",       # GKE
    "storage.googleapis.com",         # GCS
    "iam.googleapis.com",             # IAM
    "compute.googleapis.com",         # VPC / Compute
    "cloudresourcemanager.googleapis.com",
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

  project_id = var.project_id

  iceberg_bucket_name       = var.iceberg_bucket_name
  raw_events_bucket_name    = var.raw_events_bucket_name
  dbt_artifacts_bucket_name = var.dbt_artifacts_bucket_name

  depends_on = [google_project_service.apis]
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

# --- GKE Cluster ---
module "gke" {
  source = "./modules/gke"

  project_id           = var.project_id
  region               = var.region
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

  depends_on = [module.vpc]
}
