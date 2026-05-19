variable "resource_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
}

variable "lambda_source_dir" {
  description = "Source directory containing the file-processing package."
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime."
  type        = string
}

variable "lambda_architectures" {
  description = "Lambda instruction set architectures."
  type        = list(string)
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
}
