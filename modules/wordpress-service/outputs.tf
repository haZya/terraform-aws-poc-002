output "wordpress_url" {
  description = "HTTP URL for the WordPress load balancer."
  value       = "http://${aws_lb.wordpress.dns_name}"
}

output "load_balancer_dns_name" {
  description = "DNS name of the WordPress application load balancer."
  value       = aws_lb.wordpress.dns_name
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster running WordPress."
  value       = aws_ecs_cluster.wordpress.name
}

output "ecs_service_name" {
  description = "Name of the ECS service running WordPress."
  value       = aws_ecs_service.wordpress.name
}
