output "wordpress_url" {
  description = "HTTP URL for the WordPress load balancer."
  value       = module.app.wordpress_url
}

output "load_balancer_dns_name" {
  description = "DNS name of the WordPress application load balancer."
  value       = module.app.load_balancer_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster running WordPress."
  value       = module.app.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service running WordPress."
  value       = module.app.ecs_service_name
}

output "s3_files_bucket_name" {
  description = "Name of the S3 bucket backing the S3 Files file system."
  value       = module.app.s3_files_bucket_name
}

output "s3_files_file_system_id" {
  description = "S3 Files file system ID used by the ECS task volume."
  value       = module.app.s3_files_file_system_id
}

output "s3_files_access_point_id" {
  description = "S3 Files access point ID mounted by WordPress."
  value       = module.app.s3_files_access_point_id
}

output "database_endpoint" {
  description = "MariaDB endpoint for WordPress."
  value       = module.app.database_endpoint
}

output "ecr_repository_url" {
  description = "Private ECR repository URL containing the mirrored WordPress image."
  value       = module.app.ecr_repository_url
}
