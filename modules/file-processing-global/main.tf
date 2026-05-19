data "aws_caller_identity" "current" {}

locals {
  name_prefix        = "${var.app_name}-${var.environment}-file-processing"
  safe_name_prefix   = replace(lower(local.name_prefix), "/[^a-z0-9-]/", "-")
  resource_prefix    = substr(local.safe_name_prefix, 0, 40)
  bucket_prefix      = substr(local.safe_name_prefix, 0, 20)
  upload_bucket_name = "${local.bucket_prefix}-${data.aws_caller_identity.current.account_id}-uploads"
}

resource "aws_s3_bucket" "upload" {
  bucket        = local.upload_bucket_name
  force_destroy = var.force_destroy_data

  tags = {
    Name = "${local.resource_prefix}-uploads"
  }
}

resource "aws_s3_bucket_public_access_block" "upload" {
  bucket = aws_s3_bucket.upload.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "upload" {
  bucket = aws_s3_bucket.upload.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

resource "aws_cloudfront_origin_access_control" "upload" {
  name                              = "${local.resource_prefix}-uploads"
  description                       = "CloudFront access to processed upload bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "uploads" {
  name        = "${local.resource_prefix}-uploads"
  comment     = "Processed upload asset cache policy"
  default_ttl = 604800
  min_ttl     = 0
  max_ttl     = 2592000

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "uploads" {
  enabled = true
  comment = "${local.resource_prefix} processed uploads"

  origin {
    domain_name              = aws_s3_bucket.upload.bucket_regional_domain_name
    origin_id                = "upload-bucket"
    origin_access_control_id = aws_cloudfront_origin_access_control.upload.id
  }

  default_cache_behavior {
    target_origin_id       = "upload-bucket"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.uploads.id
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = {
    Name = "${local.resource_prefix}-uploads"
  }
}

data "aws_iam_policy_document" "upload_bucket" {
  statement {
    sid    = "AllowCloudFrontRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = ["${aws_s3_bucket.upload.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.uploads.arn]
    }
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.upload.arn,
      "${aws_s3_bucket.upload.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyOutdatedTLS"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.upload.arn,
      "${aws_s3_bucket.upload.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

resource "aws_s3_bucket_policy" "upload" {
  bucket = aws_s3_bucket.upload.id
  policy = data.aws_iam_policy_document.upload_bucket.json
}
