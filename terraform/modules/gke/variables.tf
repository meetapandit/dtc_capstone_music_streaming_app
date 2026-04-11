variable "project_id" { type = string }
variable "region" { type = string }
variable "zone" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "master_version" { type = string }
variable "network" { type = string }
variable "subnetwork" { type = string }
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }
variable "general_node_count" { type = number }
variable "general_machine_type" { type = string }
variable "data_node_count" { type = number }
variable "data_machine_type" { type = string }
variable "data_disk_size_gb" {
  type    = number
  default = 100
}
variable "data_disk_type" {
  type    = string
  default = "pd-standard" # pd-ssd counts against SSD_TOTAL_GB quota; pd-standard does not
}
