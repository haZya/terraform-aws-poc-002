output "upload_bucket_name" {
  description = "Name of the processed upload bucket."
  value       = aws_s3_bucket.upload.id
}

output "upload_bucket_arn" {
  description = "ARN of the processed upload bucket."
  value       = aws_s3_bucket.upload.arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for processed uploads."
  value       = aws_cloudfront_distribution.uploads.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name serving processed uploads."
  value       = aws_cloudfront_distribution.uploads.domain_name
}
