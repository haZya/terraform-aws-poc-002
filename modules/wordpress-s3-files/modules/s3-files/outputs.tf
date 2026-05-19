output "bucket_name" {
  description = "Name of the S3 bucket backing S3 Files."
  value       = aws_s3_bucket.app_files.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket backing S3 Files."
  value       = aws_s3_bucket.app_files.arn
}

output "file_system_id" {
  description = "S3 Files file system ID."
  value       = aws_s3files_file_system.wordpress.id
}

output "file_system_arn" {
  description = "S3 Files file system ARN."
  value       = aws_s3files_file_system.wordpress.arn
}

output "access_point_id" {
  description = "S3 Files access point ID."
  value       = aws_s3files_access_point.wordpress.id
}

output "access_point_arn" {
  description = "S3 Files access point ARN."
  value       = aws_s3files_access_point.wordpress.arn
}
