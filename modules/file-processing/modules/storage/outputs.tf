output "staging_bucket_id" {
  description = "Name of the staging upload bucket."
  value       = aws_s3_bucket.staging.id
}

output "staging_bucket_arn" {
  description = "ARN of the staging upload bucket."
  value       = aws_s3_bucket.staging.arn
}
