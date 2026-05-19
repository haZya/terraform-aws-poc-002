variable "resource_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the database security group."
  type        = string
}

variable "isolated_subnet_ids" {
  description = "Isolated subnet IDs for the database subnet group."
  type        = list(string)
}

variable "db_name" {
  description = "MariaDB database name for WordPress."
  type        = string
}

variable "db_master_username" {
  description = "MariaDB master username managed by RDS Secrets Manager integration."
  type        = string
}

variable "db_port" {
  description = "MariaDB listener port."
  type        = number
}

variable "db_engine_version" {
  description = "MariaDB engine version."
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class for MariaDB."
  type        = string
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
}

variable "db_max_allocated_storage" {
  description = "Maximum RDS autoscaled storage in GiB."
  type        = number
}

variable "db_storage_type" {
  description = "RDS storage type."
  type        = string
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated RDS backups."
  type        = number
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection for the WordPress database."
  type        = bool
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final RDS snapshot on destroy."
  type        = bool
}
