resource "aws_sqs_queue" "s3_object_created_dlq" {
  name                      = "${var.resource_prefix}-s3-object-created-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${var.resource_prefix}-s3-object-created-dlq"
  }
}

resource "aws_sqs_queue" "guardduty_result_dlq" {
  name                      = "${var.resource_prefix}-guardduty-result-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${var.resource_prefix}-guardduty-result-dlq"
  }
}

resource "aws_sqs_queue" "upload_status_changed_dlq" {
  name                      = "${var.resource_prefix}-upload-status-changed-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${var.resource_prefix}-upload-status-changed-dlq"
  }
}

resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${var.resource_prefix}-s3-object-created"
  description = "Register staging uploads when S3 object-created events arrive."

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [var.staging_bucket_id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "s3_object_created" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "RegisterUpload"
  arn       = module.register_upload.arn

  input_transformer {
    input_paths = {
      bucket = "$.detail.bucket.name"
      key    = "$.detail.object.key"
    }
    input_template = "{\"bucket\": <bucket>, \"key\": <key>}"
  }

  retry_policy {
    maximum_event_age_in_seconds = 180
    maximum_retry_attempts       = 4
  }

  dead_letter_config {
    arn = aws_sqs_queue.s3_object_created_dlq.arn
  }

  depends_on = [aws_sqs_queue_policy.s3_object_created_dlq]
}

resource "aws_lambda_permission" "allow_s3_event_rule" {
  statement_id  = "AllowExecutionFromS3ObjectCreatedRule"
  action        = "lambda:InvokeFunction"
  function_name = module.register_upload.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}

resource "aws_cloudwatch_event_rule" "guardduty_scan_result" {
  name        = "${var.resource_prefix}-guardduty-scan-result"
  description = "Start file processing workflow from GuardDuty malware scan results."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Malware Protection Object Scan Result"]
    detail = {
      resourceType = ["S3_OBJECT"]
      s3ObjectDetails = {
        bucketName = [var.staging_bucket_id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "guardduty_scan_result" {
  rule      = aws_cloudwatch_event_rule.guardduty_scan_result.name
  target_id = "FileUploadStateMachine"
  arn       = aws_sfn_state_machine.file_upload.arn
  role_arn  = aws_iam_role.eventbridge_state_machine.arn

  input_transformer {
    input_paths = {
      bucket      = "$.detail.s3ObjectDetails.bucketName"
      key         = "$.detail.s3ObjectDetails.objectKey"
      scan_status = "$.detail.scanStatus"
      scan_result = "$.detail.scanResultDetails.scanResultStatus"
      threats     = "$.detail.scanResultDetails.threats"
    }
    input_template = "{\"bucket\": <bucket>, \"key\": <key>, \"scanStatus\": <scan_status>, \"scanResultStatus\": <scan_result>, \"threats\": <threats>}"
  }

  retry_policy {
    maximum_retry_attempts = 5
  }

  dead_letter_config {
    arn = aws_sqs_queue.guardduty_result_dlq.arn
  }

  depends_on = [aws_sqs_queue_policy.guardduty_result_dlq]
}

resource "aws_cloudwatch_event_rule" "upload_status_changed" {
  name           = "${var.resource_prefix}-upload-status-changed"
  description    = "Fan out upload status changes to active WebSocket clients."
  event_bus_name = aws_cloudwatch_event_bus.file_processing.name

  event_pattern = jsonencode({
    detail-type = ["UploadStatusChanged"]
  })
}

resource "aws_cloudwatch_event_target" "upload_status_changed" {
  event_bus_name = aws_cloudwatch_event_bus.file_processing.name
  rule           = aws_cloudwatch_event_rule.upload_status_changed.name
  target_id      = "EmitUploadStatus"
  arn            = module.emit_upload_status.arn
  input_path     = "$.detail"

  retry_policy {
    maximum_retry_attempts = 5
  }

  dead_letter_config {
    arn = aws_sqs_queue.upload_status_changed_dlq.arn
  }

  depends_on = [aws_sqs_queue_policy.upload_status_changed_dlq]
}

resource "aws_lambda_permission" "allow_upload_status_changed_rule" {
  statement_id  = "AllowExecutionFromUploadStatusChangedRule"
  action        = "lambda:InvokeFunction"
  function_name = module.emit_upload_status.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.upload_status_changed.arn
}

data "aws_iam_policy_document" "s3_object_created_dlq" {
  statement {
    sid       = "AllowEventBridgeToSendMessages"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.s3_object_created_dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.s3_object_created.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.s3_object_created_dlq.arn]

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
}

data "aws_iam_policy_document" "guardduty_result_dlq" {
  statement {
    sid       = "AllowEventBridgeToSendMessages"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.guardduty_result_dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.guardduty_scan_result.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.guardduty_result_dlq.arn]

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
}

data "aws_iam_policy_document" "upload_status_changed_dlq" {
  statement {
    sid       = "AllowEventBridgeToSendMessages"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.upload_status_changed_dlq.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.upload_status_changed.arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.upload_status_changed_dlq.arn]

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
}

resource "aws_sqs_queue_policy" "s3_object_created_dlq" {
  queue_url = aws_sqs_queue.s3_object_created_dlq.id
  policy    = data.aws_iam_policy_document.s3_object_created_dlq.json
}

resource "aws_sqs_queue_policy" "guardduty_result_dlq" {
  queue_url = aws_sqs_queue.guardduty_result_dlq.id
  policy    = data.aws_iam_policy_document.guardduty_result_dlq.json
}

resource "aws_sqs_queue_policy" "upload_status_changed_dlq" {
  queue_url = aws_sqs_queue.upload_status_changed_dlq.id
  policy    = data.aws_iam_policy_document.upload_status_changed_dlq.json
}
