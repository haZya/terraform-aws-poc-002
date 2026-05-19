output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "private_subnet_ids_by_az" {
  description = "Private subnet IDs keyed by availability zone."
  value       = { for az_name, subnet in aws_subnet.private : az_name => subnet.id }
}

output "isolated_subnet_ids" {
  description = "Isolated subnet IDs."
  value       = [for subnet in aws_subnet.isolated : subnet.id]
}
