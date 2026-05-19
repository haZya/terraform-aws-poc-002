output "file_processing_upload_bucket_name" {
  description = "Name of the global processed file-processing upload bucket."
  value       = module.file_processing_global.upload_bucket_name
}

output "file_processing_cloudfront_domain_name" {
  description = "CloudFront domain name serving processed uploads."
  value       = module.file_processing_global.cloudfront_domain_name
}

output "file_processing_cloudfront_distribution_id" {
  description = "CloudFront distribution ID serving processed uploads."
  value       = module.file_processing_global.cloudfront_distribution_id
}
