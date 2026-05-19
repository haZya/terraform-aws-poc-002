output "repository_url" {
  description = "Private ECR repository URL."
  value       = aws_ecr_repository.wordpress.repository_url
}

output "image_uri" {
  description = "Private ECR WordPress image URI."
  value       = local.image_uri
}
