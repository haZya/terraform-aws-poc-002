data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["malware-protection-plan.guardduty.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "malware_scan" {
  name               = "${var.resource_prefix}-guardduty-s3"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${var.resource_prefix}-guardduty-s3"
  }
}

data "aws_iam_policy_document" "malware_scan" {
  statement {
    sid = "AllowManagedRuleToSendS3EventsToGuardDuty"
    actions = [
      "events:PutRule",
      "events:DeleteRule",
      "events:PutTargets",
      "events:RemoveTargets",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:rule/DO-NOT-DELETE-AmazonGuardDutyMalwareProtectionS3*"]

    condition {
      test     = "StringLike"
      variable = "events:ManagedBy"
      values   = ["malware-protection-plan.guardduty.amazonaws.com"]
    }
  }

  statement {
    sid = "AllowGuardDutyToMonitorEventBridgeManagedRule"
    actions = [
      "events:DescribeRule",
      "events:ListTargetsByRule",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:events:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:rule/DO-NOT-DELETE-AmazonGuardDutyMalwareProtectionS3*"]
  }

  statement {
    sid = "AllowPostScanTag"
    actions = [
      "s3:PutObjectTagging",
      "s3:GetObjectTagging",
      "s3:PutObjectVersionTagging",
      "s3:GetObjectVersionTagging",
    ]
    resources = ["${var.staging_bucket_arn}/*"]
  }

  statement {
    sid = "AllowEnableS3EventBridgeEvents"
    actions = [
      "s3:PutBucketNotification",
      "s3:GetBucketNotification",
    ]
    resources = [var.staging_bucket_arn]
  }

  statement {
    sid       = "AllowPutValidationObject"
    actions   = ["s3:PutObject"]
    resources = ["${var.staging_bucket_arn}/malware-protection-resource-validation-object"]
  }

  statement {
    sid = "AllowCheckBucketOwnership"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [var.staging_bucket_arn]
  }

  statement {
    sid = "AllowMalwareScan"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["${var.staging_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "malware_scan" {
  name   = "GuardDutyMalwareProtectionRolePolicy"
  role   = aws_iam_role.malware_scan.id
  policy = data.aws_iam_policy_document.malware_scan.json
}

resource "aws_guardduty_malware_protection_plan" "staging" {
  role = aws_iam_role.malware_scan.arn

  protected_resource {
    s3_bucket {
      bucket_name = var.staging_bucket_id
    }
  }

  actions {
    tagging {
      status = "ENABLED"
    }
  }

  tags = {
    Name = "${var.resource_prefix}-staging"
  }

  depends_on = [aws_iam_role_policy.malware_scan]
}
