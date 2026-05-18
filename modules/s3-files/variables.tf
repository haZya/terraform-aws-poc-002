variable "resource_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket backing the S3 Files file system."
  type        = string
}

variable "force_destroy_data" {
  description = "Whether the backing S3 bucket is force-deleted on destroy."
  type        = bool
}

variable "vpc_id" {
  description = "VPC ID for the S3 Files mount target security group."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR allowed to access S3 Files mount targets over NFS."
  type        = string
}

variable "private_subnet_ids_by_az" {
  description = "Private subnet IDs keyed by availability zone for S3 Files mount targets."
  type        = map(string)
}

variable "wordpress_posix_uid" {
  description = "POSIX UID used by the S3 Files access point for WordPress files."
  type        = number
}

variable "wordpress_posix_gid" {
  description = "POSIX GID used by the S3 Files access point for WordPress files."
  type        = number
}
