variable "project_id" { type = string }
variable "project_number" {
  description = "Numeric GCP project number — used to construct the Composer Service Agent email"
  type        = string
}
variable "iceberg_bucket_name" { type = string }
variable "raw_events_bucket_name" { type = string }
variable "dbt_artifacts_bucket_name" { type = string }
