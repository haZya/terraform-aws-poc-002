variable "resource_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
}

variable "force_destroy_data" {
  description = "Whether the ECR repository is force-deleted on destroy."
  type        = bool
}

variable "aws_cli_profile" {
  description = "Optional AWS CLI profile used by the local image mirroring command."
  type        = string
  default     = null
}

variable "mirror_wordpress_image" {
  description = "Whether Terraform should mirror the public Bitnami WordPress image into the private ECR repository with AWS CLI and Docker."
  type        = bool
}

variable "wordpress_source_image" {
  description = "Source WordPress image to mirror into private ECR."
  type        = string
}

variable "wordpress_image_tag" {
  description = "Destination tag for the mirrored WordPress image in private ECR."
  type        = string
}

variable "wordpress_image_platform" {
  description = "Docker platform to pull and push for the WordPress image."
  type        = string
}
