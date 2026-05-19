output "connections_table_name" {
  description = "WebSocket connections table name."
  value       = aws_dynamodb_table.connections.name
}

output "connections_table_arn" {
  description = "WebSocket connections table ARN."
  value       = aws_dynamodb_table.connections.arn
}

output "connections_table_stream_arn" {
  description = "WebSocket connections table stream ARN."
  value       = aws_dynamodb_table.connections.stream_arn
}

output "api_id" {
  description = "WebSocket API ID."
  value       = aws_apigatewayv2_api.websocket.id
}

output "api_execution_arn" {
  description = "WebSocket API execution ARN."
  value       = aws_apigatewayv2_api.websocket.execution_arn
}

output "websocket_endpoint" {
  description = "WebSocket client endpoint."
  value       = "wss://${aws_apigatewayv2_api.websocket.id}.execute-api.${data.aws_region.current.id}.${data.aws_partition.current.dns_suffix}/${aws_apigatewayv2_stage.prod.name}"
}

output "callback_url" {
  description = "API Gateway management callback URL."
  value       = "https://${aws_apigatewayv2_api.websocket.id}.execute-api.${data.aws_region.current.id}.${data.aws_partition.current.dns_suffix}/${aws_apigatewayv2_stage.prod.name}"
}
