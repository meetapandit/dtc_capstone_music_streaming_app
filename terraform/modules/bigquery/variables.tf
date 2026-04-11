variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for the BigQuery connection (must match BigQuery dataset location)"
  type        = string
}

variable "connection_id" {
  description = "ID for the BigQuery Cloud Resource Connection"
  type        = string
  default     = "bigquery-iceberg-connection"
}

variable "iceberg_bucket_name" {
  description = "GCS bucket holding Iceberg data and metadata files"
  type        = string
}
