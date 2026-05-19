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

variable "staging_bucket_id" {
  description = "Staging bucket name."
  type        = string
}

variable "staging_bucket_arn" {
  description = "Staging bucket ARN."
  type        = string
}

variable "upload_bucket_id" {
  description = "Processed upload bucket name."
  type        = string
}

variable "upload_bucket_arn" {
  description = "Processed upload bucket ARN."
  type        = string
}

variable "uploads_table_name" {
  description = "Uploads table name."
  type        = string
}

variable "uploads_table_arn" {
  description = "Uploads table ARN."
  type        = string
}

variable "uploads_table_stream_arn" {
  description = "Uploads table stream ARN."
  type        = string
}

variable "upload_relations_table_name" {
  description = "Upload relations table name."
  type        = string
}

variable "upload_relations_table_arn" {
  description = "Upload relations table ARN."
  type        = string
}

variable "connections_table_name" {
  description = "WebSocket connections table name."
  type        = string
}

variable "connections_table_arn" {
  description = "WebSocket connections table ARN."
  type        = string
}

variable "websocket_api_id" {
  description = "WebSocket API ID."
  type        = string
}

variable "websocket_api_execution_arn" {
  description = "WebSocket API execution ARN."
  type        = string
}

variable "websocket_callback_url" {
  description = "API Gateway management callback URL."
  type        = string
}
