data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  uploads_table_resources = [
    var.uploads_table_arn,
    "${var.uploads_table_arn}/index/*",
  ]
  upload_relations_table_resources = [var.upload_relations_table_arn]
  staging_object_resources         = ["${var.staging_bucket_arn}/*"]
  upload_object_resources          = ["${var.upload_bucket_arn}/*"]
}

data "aws_iam_policy_document" "register_upload" {
  statement {
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
    ]
    resources = local.uploads_table_resources
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = local.staging_object_resources
  }
}

data "aws_iam_policy_document" "generate_presigned_post" {
  statement {
    actions   = ["s3:PutObject"]
    resources = local.staging_object_resources
  }
}

data "aws_iam_policy_document" "validate_file" {
  statement {
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
    ]
    resources = local.uploads_table_resources
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = local.staging_object_resources
  }
}

data "aws_iam_policy_document" "transform_image" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = local.upload_object_resources
  }
}

data "aws_iam_policy_document" "copy_to_upload_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = local.staging_object_resources
  }

  statement {
    actions   = ["s3:PutObject"]
    resources = local.upload_object_resources
  }
}

data "aws_iam_policy_document" "add_metadata" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
    ]
    resources = local.uploads_table_resources
  }
}

data "aws_iam_policy_document" "update_status" {
  statement {
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
    ]
    resources = concat(local.uploads_table_resources, local.upload_relations_table_resources)
  }
}

data "aws_iam_policy_document" "cleanup_replaced_upload" {
  statement {
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
    ]
    resources = local.uploads_table_resources
  }

  statement {
    actions   = ["s3:DeleteObject"]
    resources = local.upload_object_resources
  }
}

data "aws_iam_policy_document" "emit_upload_status" {
  statement {
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
    ]
    resources = [var.connections_table_arn]
  }

  statement {
    actions   = ["execute-api:ManageConnections"]
    resources = ["${var.websocket_api_execution_arn}/*"]
  }
}

data "aws_iam_policy_document" "state_machine_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "state_machine" {
  name               = "${var.resource_prefix}-file-workflow"
  assume_role_policy = data.aws_iam_policy_document.state_machine_assume_role.json

  tags = {
    Name = "${var.resource_prefix}-file-workflow"
  }
}

data "aws_iam_policy_document" "state_machine" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.validate_file.arn,
      module.resolve_final_key.arn,
      module.copy_to_upload_bucket.arn,
      module.transform_image.arn,
      module.add_metadata.arn,
      module.update_upload_status.arn,
      module.cleanup_replaced_upload.arn,
    ]
  }

  statement {
    actions   = ["s3:DeleteObject"]
    resources = local.staging_object_resources
  }

  statement {
    actions   = ["events:PutEvents"]
    resources = [aws_cloudwatch_event_bus.file_processing.arn]
  }

  statement {
    actions = [
      "logs:CreateLogDelivery",
      "logs:GetLogDelivery",
      "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries",
      "logs:PutResourcePolicy",
      "logs:DescribeResourcePolicies",
      "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "state_machine" {
  name   = "${var.resource_prefix}-file-workflow"
  role   = aws_iam_role.state_machine.id
  policy = data.aws_iam_policy_document.state_machine.json
}

data "aws_iam_policy_document" "eventbridge_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge_state_machine" {
  name               = "${var.resource_prefix}-events-sfn"
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role.json

  tags = {
    Name = "${var.resource_prefix}-events-sfn"
  }
}

data "aws_iam_policy_document" "eventbridge_state_machine" {
  statement {
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.file_upload.arn]
  }
}

resource "aws_iam_role_policy" "eventbridge_state_machine" {
  name   = "${var.resource_prefix}-events-sfn"
  role   = aws_iam_role.eventbridge_state_machine.id
  policy = data.aws_iam_policy_document.eventbridge_state_machine.json
}
