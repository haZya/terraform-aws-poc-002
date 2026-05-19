variable "app_name" {
  description = "Application name used for resource names and tags."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.app_name))
    error_message = "app_name must be 3-32 lowercase alphanumeric or hyphen characters, start with a letter, and end with a letter or number."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.environment))
    error_message = "environment must be 3-22 lowercase alphanumeric or hyphen characters, start with a letter, and end with a letter or number."
  }
}

variable "force_destroy_data" {
  description = "Whether demo data stores such as S3 buckets are force-deleted on destroy."
  type        = bool
  default     = true
}
