output "queue_arn" {
  description = "ARN of the application queue."
  value       = aws_sqs_queue.main.arn
}

output "queue_name" {
  description = "Name of the application queue."
  value       = aws_sqs_queue.main.name
}

output "queue_url" {
  description = "URL of the application queue."
  value       = aws_sqs_queue.main.url
}
