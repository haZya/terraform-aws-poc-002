output "address" {
  description = "MariaDB hostname."
  value       = aws_db_instance.wordpress.address
}

output "endpoint" {
  description = "MariaDB endpoint in address:port format."
  value       = aws_db_instance.wordpress.endpoint
}

output "port" {
  description = "MariaDB listener port."
  value       = aws_db_instance.wordpress.port
}

output "security_group_id" {
  description = "Database security group ID."
  value       = aws_security_group.database.id
}

output "secret_arn" {
  description = "RDS-managed Secrets Manager secret ARN."
  value       = aws_db_instance.wordpress.master_user_secret[0].secret_arn
}
