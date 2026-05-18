variable "resource_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where WordPress runs."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the application load balancer."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ECS service."
  type        = list(string)
}

variable "wordpress_image" {
  description = "WordPress container image URI."
  type        = string
}

variable "wordpress_desired_count" {
  description = "Desired number of WordPress Fargate tasks."
  type        = number
}

variable "wordpress_cpu" {
  description = "Fargate task CPU units for WordPress."
  type        = number
}

variable "wordpress_memory" {
  description = "Fargate task memory in MiB for WordPress."
  type        = number
}

variable "wordpress_container_port" {
  description = "Container port exposed by WordPress."
  type        = number
}

variable "wordpress_admin_username" {
  description = "Initial WordPress administrator username."
  type        = string
}

variable "wordpress_admin_password" {
  description = "Initial WordPress administrator password."
  type        = string
  sensitive   = true
}

variable "wordpress_admin_email" {
  description = "Initial WordPress administrator email."
  type        = string
}

variable "wordpress_blog_name" {
  description = "Initial WordPress site name."
  type        = string
}

variable "db_name" {
  description = "MariaDB database name for WordPress."
  type        = string
}

variable "db_port" {
  description = "MariaDB listener port."
  type        = number
}

variable "database_address" {
  description = "MariaDB hostname."
  type        = string
}

variable "database_secret_arn" {
  description = "RDS-managed Secrets Manager secret ARN."
  type        = string
}

variable "database_security_group_id" {
  description = "Database security group ID to allow ECS ingress from."
  type        = string
}

variable "s3_files_bucket_arn" {
  description = "ARN of the S3 bucket backing S3 Files."
  type        = string
}

variable "s3_files_file_system_arn" {
  description = "S3 Files file system ARN mounted by WordPress."
  type        = string
}

variable "s3_files_access_point_arn" {
  description = "S3 Files access point ARN mounted by WordPress."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for WordPress container logs."
  type        = number
}

variable "enable_container_insights" {
  description = "Whether to enable ECS Container Insights on the cluster."
  type        = bool
}
