resource "google_container_cluster" "primary" {
  provider = google-beta

  name     = "${var.environment}-${var.cluster_name}"
  project  = var.project_id
  location = var.zone # zonal cluster — single zone, fits within free-tier quota

  # Remove the default node pool — we manage our own
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  network    = var.network
  subnetwork = var.subnetwork

  # Use VPC-native networking (required for Workload Identity + private cluster)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Enable Workload Identity — lets K8s service accounts impersonate GCP SAs
  # This is how Flink, Trino, etc. access GCS without key files
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Private cluster — nodes have no public IPs
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false # keep public endpoint for kubectl access
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  release_channel {
    channel = "REGULAR"
  }

  # Enable Kubernetes network policies
  network_policy {
    enabled = true
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"
}

# --- Node Pool: General Purpose ---
# Runs: Airflow, Superset, eventsim, Kafka (light workloads)
resource "google_container_node_pool" "general" {
  name       = "general-pool"
  project    = var.project_id
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.general_node_count

  node_config {
    machine_type = var.general_machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"

    # Workload Identity for nodes
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      env  = var.environment
      pool = "general"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "60m" # pod drain + node deletion can exceed the 30m default
  }
}

# --- Node Pool: Data Services ---
# Runs: Flink, ClickHouse, Trino (memory-heavy workloads)
resource "google_container_node_pool" "data" {
  name       = "data-pool"
  project    = var.project_id
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.data_node_count

  node_config {
    machine_type = var.data_machine_type
    disk_size_gb = var.data_disk_size_gb
    disk_type    = var.data_disk_type

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    labels = {
      env  = var.environment
      pool = "data"
    }

    # Taint data nodes so only data workloads schedule here
    taint {
      key    = "workload"
      value  = "data"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 2
  }

  timeouts {
    create = "30m"
    update = "30m"
    delete = "60m"
  }
}
