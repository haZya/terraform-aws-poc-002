variable "resource_prefix" {
  description = "Prefix used for resource names and Name tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "max_azs" {
  description = "Maximum number of availability zones to use."
  type        = number

  validation {
    condition     = var.max_azs >= 2 && var.max_azs <= 3
    error_message = "max_azs must be between 2 and 3."
  }
}
