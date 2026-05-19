variable "resource_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
}

variable "staging_bucket_id" {
  description = "Name of the staging upload bucket."
  type        = string
}

variable "staging_bucket_arn" {
  description = "ARN of the staging upload bucket."
  type        = string
}
