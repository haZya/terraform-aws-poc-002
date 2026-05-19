variable "function_name" {
  description = "Lambda function name."
  type        = string
}

variable "source_dir" {
  description = "Source directory containing the file-processing package."
  type        = string
}

variable "entry" {
  description = "Lambda TypeScript entrypoint relative to source_dir."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
}

variable "architectures" {
  description = "Lambda instruction set architectures."
  type        = list(string)
}

variable "environment" {
  description = "Lambda environment variables."
  type        = map(string)
  default     = {}
}

variable "timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 3
}

variable "memory_size" {
  description = "Lambda memory size in MiB."
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
}

variable "include_sharp" {
  description = "Whether to package sharp as a Lambda Linux native dependency."
  type        = bool
  default     = false
}

variable "policy_jsons" {
  description = "Inline IAM policy JSON documents for the Lambda role. Use a list so policy count is known even when JSON contains apply-time ARNs."
  type        = list(string)
  default     = []
}
