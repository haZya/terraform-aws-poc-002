output "queue_arn" {
  description = "ARN of the application queue."
  value       = module.app.queue_arn
}

output "queue_name" {
  description = "Name of the application queue."
  value       = module.app.queue_name
}

output "queue_url" {
  description = "URL of the application queue."
  value       = module.app.queue_url
}
