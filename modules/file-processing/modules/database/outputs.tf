output "uploads_table_name" {
  description = "Uploads table name."
  value       = aws_dynamodb_table.uploads.name
}

output "uploads_table_arn" {
  description = "Uploads table ARN."
  value       = aws_dynamodb_table.uploads.arn
}

output "uploads_table_stream_arn" {
  description = "Uploads table stream ARN."
  value       = aws_dynamodb_table.uploads.stream_arn
}

output "upload_relations_table_name" {
  description = "Upload relations table name."
  value       = aws_dynamodb_table.upload_relations.name
}

output "upload_relations_table_arn" {
  description = "Upload relations table ARN."
  value       = aws_dynamodb_table.upload_relations.arn
}
