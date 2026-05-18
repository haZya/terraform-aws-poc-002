data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "app_files" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy_data

  tags = {
    Name = "${var.resource_prefix}-files"
  }
}

resource "aws_s3_bucket_public_access_block" "app_files" {
  bucket = aws_s3_bucket.app_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "app_files" {
  bucket = aws_s3_bucket.app_files.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "s3_files_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elasticfilesystem.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:s3files:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:file-system/*"]
    }
  }
}

resource "aws_iam_role" "s3_files_bucket" {
  name               = "${var.resource_prefix}-s3-files-bucket"
  assume_role_policy = data.aws_iam_policy_document.s3_files_assume_role.json

  tags = {
    Name = "${var.resource_prefix}-s3-files-bucket"
  }
}

data "aws_iam_policy_document" "s3_files_bucket" {
  statement {
    sid = "S3BucketPermissions"
    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
    ]
    resources = [aws_s3_bucket.app_files.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid = "S3ObjectPermissions"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject*",
      "s3:GetObject*",
      "s3:List*",
      "s3:PutObject*",
    ]
    resources = ["${aws_s3_bucket.app_files.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid = "EventBridgeManage"
    actions = [
      "events:DeleteRule",
      "events:DisableRule",
      "events:EnableRule",
      "events:PutRule",
      "events:PutTargets",
      "events:RemoveTargets",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:events:*:*:rule/DO-NOT-DELETE-S3-Files*"]

    condition {
      test     = "StringEquals"
      variable = "events:ManagedBy"
      values   = ["elasticfilesystem.amazonaws.com"]
    }
  }

  statement {
    sid = "EventBridgeRead"
    actions = [
      "events:DescribeRule",
      "events:ListRuleNamesByTarget",
      "events:ListRules",
      "events:ListTargetsByRule",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:events:*:*:rule/*"]
  }
}

resource "aws_iam_role_policy" "s3_files_bucket" {
  name   = "${var.resource_prefix}-s3-files-bucket"
  role   = aws_iam_role.s3_files_bucket.id
  policy = data.aws_iam_policy_document.s3_files_bucket.json
}

resource "aws_s3files_file_system" "wordpress" {
  bucket                = aws_s3_bucket.app_files.arn
  role_arn              = aws_iam_role.s3_files_bucket.arn
  accept_bucket_warning = true

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }

  depends_on = [aws_iam_role_policy.s3_files_bucket]
}

resource "aws_s3files_access_point" "wordpress" {
  file_system_id = aws_s3files_file_system.wordpress.id

  posix_user {
    gid = var.wordpress_posix_gid
    uid = var.wordpress_posix_uid
  }

  root_directory {
    path = "/wordpress"

    creation_permissions {
      owner_gid   = var.wordpress_posix_gid
      owner_uid   = var.wordpress_posix_uid
      permissions = "755"
    }
  }

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }
}

resource "aws_security_group" "s3_files_mount" {
  name        = "${var.resource_prefix}-s3-files-mount"
  description = "S3 Files mount target security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.resource_prefix}-s3-files-mount"
  }
}

resource "aws_vpc_security_group_ingress_rule" "s3_files_mount_nfs" {
  security_group_id = aws_security_group.s3_files_mount.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 2049
  ip_protocol       = "tcp"
  to_port           = 2049
}

resource "aws_vpc_security_group_egress_rule" "s3_files_mount_all" {
  security_group_id = aws_security_group.s3_files_mount.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_s3files_mount_target" "wordpress" {
  for_each = var.private_subnet_ids_by_az

  file_system_id  = aws_s3files_file_system.wordpress.id
  subnet_id       = each.value
  security_groups = [aws_security_group.s3_files_mount.id]
}
