output "network_name" {
  value = google_compute_network.vpc.name
}

output "subnet_name" {
  value = google_compute_subnetwork.gke_subnet.name
}

output "pods_range_name" {
  value = "gke-pods"
}

output "services_range_name" {
  value = "gke-services"
}
