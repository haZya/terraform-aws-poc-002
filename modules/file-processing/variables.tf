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

variable "lambda_source_dir" {
  description = "Optional override for the file-processing Lambda package directory. Defaults to this Terraform module, which contains package.json and lambda/ sources."
  type        = string
  default     = null
}

variable "install_lambda_dependencies" {
  description = "Whether Terraform should run npm ci or npm install in the file-processing source directory before packaging Lambdas."
  type        = bool
  default     = true
}

variable "force_destroy_data" {
  description = "Whether demo data stores such as S3 buckets are force-deleted on destroy."
  type        = bool
  default     = true
}

variable "lambda_runtime" {
  description = "Node.js Lambda runtime for file-processing handlers."
  type        = string
  default     = "nodejs22.x"
}

variable "lambda_architectures" {
  description = "Lambda instruction set architectures. The sharp bundle is built for x86_64 by default."
  type        = list(string)
  default     = ["x86_64"]
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for Lambda and Step Functions logs."
  type        = number
  default     = 7
}
