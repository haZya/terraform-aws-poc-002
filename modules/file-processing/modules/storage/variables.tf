variable "resource_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
}

variable "staging_bucket_name" {
  description = "Name of the staging upload bucket."
  type        = string
}

variable "force_destroy_data" {
  description = "Whether S3 buckets are force-deleted on destroy."
  type        = bool
}
