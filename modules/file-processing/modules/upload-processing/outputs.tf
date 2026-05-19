output "generate_presigned_post_lambda_name" {
  description = "Lambda function name for generating presigned S3 POSTs."
  value       = module.generate_presigned_post.function_name
}

output "state_machine_arn" {
  description = "Step Functions state machine ARN."
  value       = aws_sfn_state_machine.file_upload.arn
}

output "event_bus_name" {
  description = "Internal EventBridge bus name."
  value       = aws_cloudwatch_event_bus.file_processing.name
}
