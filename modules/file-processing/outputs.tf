output "staging_bucket_name" {
  description = "Name of the untrusted staging upload bucket."
  value       = module.storage.staging_bucket_id
}

output "upload_bucket_name" {
  description = "Name of the global processed upload bucket used by regional processing workflows."
  value       = local.upload_bucket_name
}

output "websocket_api_endpoint" {
  description = "WebSocket API endpoint for upload status notifications."
  value       = module.websocket.websocket_endpoint
}

output "websocket_callback_url" {
  description = "API Gateway management callback URL used by status fan-out."
  value       = module.websocket.callback_url
}

output "generate_presigned_post_lambda_name" {
  description = "Lambda function name for generating presigned S3 POSTs. The CDK demo deploys this function but does not expose it through API Gateway."
  value       = module.upload_processing.generate_presigned_post_lambda_name
}

output "state_machine_arn" {
  description = "Step Functions state machine ARN for file processing."
  value       = module.upload_processing.state_machine_arn
}

output "event_bus_name" {
  description = "Internal EventBridge bus for file-processing domain events."
  value       = module.upload_processing.event_bus_name
}
