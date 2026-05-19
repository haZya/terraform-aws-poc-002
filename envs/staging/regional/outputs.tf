output "wordpress_url" {
  description = "HTTP URL for the WordPress load balancer."
  value       = module.wordpress_s3_files.wordpress_url
}

output "load_balancer_dns_name" {
  description = "DNS name of the WordPress application load balancer."
  value       = module.wordpress_s3_files.load_balancer_dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster running WordPress."
  value       = module.wordpress_s3_files.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service running WordPress."
  value       = module.wordpress_s3_files.ecs_service_name
}

output "s3_files_bucket_name" {
  description = "Name of the S3 bucket backing the S3 Files file system."
  value       = module.wordpress_s3_files.s3_files_bucket_name
}

output "s3_files_file_system_id" {
  description = "S3 Files file system ID used by the ECS task volume."
  value       = module.wordpress_s3_files.s3_files_file_system_id
}

output "s3_files_access_point_id" {
  description = "S3 Files access point ID mounted by WordPress."
  value       = module.wordpress_s3_files.s3_files_access_point_id
}

output "database_endpoint" {
  description = "MariaDB endpoint for WordPress."
  value       = module.wordpress_s3_files.database_endpoint
}

output "ecr_repository_url" {
  description = "Private ECR repository URL containing the mirrored WordPress image."
  value       = module.wordpress_s3_files.ecr_repository_url
}

output "file_processing_staging_bucket_name" {
  description = "Name of the untrusted file-processing staging upload bucket."
  value       = module.file_processing.staging_bucket_name
}

output "file_processing_upload_bucket_name" {
  description = "Name of the global processed file-processing upload bucket used by this regional workflow."
  value       = module.file_processing.upload_bucket_name
}

output "file_processing_websocket_api_endpoint" {
  description = "WebSocket API endpoint for upload status notifications."
  value       = module.file_processing.websocket_api_endpoint
}

output "file_processing_generate_presigned_post_lambda_name" {
  description = "Lambda function name for generating presigned S3 POSTs."
  value       = module.file_processing.generate_presigned_post_lambda_name
}

output "file_processing_state_machine_arn" {
  description = "Step Functions state machine ARN for file processing."
  value       = module.file_processing.state_machine_arn
}
