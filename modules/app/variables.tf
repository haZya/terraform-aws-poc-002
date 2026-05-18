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

variable "aws_cli_profile" {
  description = "Optional AWS CLI profile used by the local image mirroring command."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for the regional WordPress VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "max_azs" {
  description = "Maximum number of availability zones to use for public, private, and isolated subnets."
  type        = number
  default     = 2

  validation {
    condition     = var.max_azs >= 2 && var.max_azs <= 3
    error_message = "max_azs must be between 2 and 3 because the application load balancer requires at least two subnets."
  }
}

variable "force_destroy_data" {
  description = "Whether demo data stores such as the S3 files bucket and ECR repository are force-deleted on destroy."
  type        = bool
  default     = true
}

variable "mirror_wordpress_image" {
  description = "Whether Terraform should mirror the public Bitnami WordPress image into the private ECR repository with AWS CLI and Docker."
  type        = bool
  default     = true
}

variable "wordpress_source_image" {
  description = "Source WordPress image to mirror into private ECR."
  type        = string
  default     = "public.ecr.aws/bitnami/wordpress:latest"
}

variable "wordpress_image_tag" {
  description = "Destination tag for the mirrored WordPress image in private ECR."
  type        = string
  default     = "latest"
}

variable "wordpress_image_platform" {
  description = "Docker platform to pull and push for the WordPress image."
  type        = string
  default     = "linux/amd64"
}

variable "wordpress_desired_count" {
  description = "Desired number of WordPress Fargate tasks."
  type        = number
  default     = 2

  validation {
    condition     = var.wordpress_desired_count >= 1
    error_message = "wordpress_desired_count must be at least 1."
  }
}

variable "wordpress_cpu" {
  description = "Fargate task CPU units for WordPress."
  type        = number
  default     = 256
}

variable "wordpress_memory" {
  description = "Fargate task memory in MiB for WordPress."
  type        = number
  default     = 512
}

variable "wordpress_container_port" {
  description = "Container port exposed by the Bitnami WordPress image."
  type        = number
  default     = 8080
}

variable "wordpress_admin_username" {
  description = "Initial WordPress administrator username."
  type        = string
  default     = "admin"
}

variable "wordpress_admin_password" {
  description = "Initial WordPress administrator password. Change this for non-demo deployments."
  type        = string
  default     = "change-me-admin-password"
  sensitive   = true
}

variable "wordpress_admin_email" {
  description = "Initial WordPress administrator email."
  type        = string
  default     = "admin@example.com"
}

variable "wordpress_blog_name" {
  description = "Initial WordPress site name."
  type        = string
  default     = "WordPress Demo"
}

variable "wordpress_posix_uid" {
  description = "POSIX UID used by the S3 Files access point for WordPress files."
  type        = number
  default     = 1001
}

variable "wordpress_posix_gid" {
  description = "POSIX GID used by the S3 Files access point for WordPress files."
  type        = number
  default     = 1001
}

variable "db_name" {
  description = "MariaDB database name for WordPress."
  type        = string
  default     = "bitnami_wordpress"
}

variable "db_master_username" {
  description = "MariaDB master username managed by RDS Secrets Manager integration."
  type        = string
  default     = "admin"
}

variable "db_port" {
  description = "MariaDB listener port."
  type        = number
  default     = 3306
}

variable "db_engine_version" {
  description = "MariaDB engine version."
  type        = string
  default     = "11.8.6"
}

variable "db_instance_class" {
  description = "RDS instance class for MariaDB."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Initial RDS storage in GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum RDS autoscaled storage in GiB."
  type        = number
  default     = 100
}

variable "db_storage_type" {
  description = "RDS storage type."
  type        = string
  default     = "gp2"
}

variable "db_backup_retention_period" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 0
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection for the WordPress database."
  type        = bool
  default     = false
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final RDS snapshot on destroy."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for WordPress container logs."
  type        = number
  default     = 14
}

variable "enable_container_insights" {
  description = "Whether to enable ECS Container Insights on the cluster."
  type        = bool
  default     = false
}
