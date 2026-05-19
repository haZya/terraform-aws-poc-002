locals {
  lambda_retry = [
    {
      ErrorEquals = [
        "Lambda.ServiceException",
        "Lambda.AWSLambdaException",
        "Lambda.SdkClientException",
        "States.TaskFailed",
        "States.Timeout",
      ]
      IntervalSeconds = 2
      BackoffRate     = 2
      MaxAttempts     = 3
    }
  ]

  s3_retry = [
    {
      ErrorEquals = [
        "S3.InternalError",
        "S3.ServiceUnavailable",
        "ThrottlingException",
        "States.ServiceException",
        "States.ServiceUnavailable",
        "States.TaskFailed",
        "States.Timeout",
      ]
      IntervalSeconds = 2
      BackoffRate     = 2
      MaxAttempts     = 3
    }
  ]

  eventbridge_retry = [
    {
      ErrorEquals = [
        "EventBridge.InternalException",
        "EventBridge.ThrottlingException",
        "States.ServiceException",
        "States.ServiceUnavailable",
        "States.TaskFailed",
        "States.Timeout",
      ]
      IntervalSeconds = 2
      BackoffRate     = 2
      MaxAttempts     = 3
    }
  ]

  state_machine_definition = jsonencode({
    Comment = "Secure file upload processing workflow"
    StartAt = "MainWorkflowGroup"
    States = {
      MainWorkflowGroup = {
        Type       = "Parallel"
        OutputPath = "$[0]"
        Branches = [
          {
            StartAt = "ScanResultOK"
            States = {
              ScanResultOK = {
                Type = "Choice"
                Choices = [
                  {
                    Variable     = "$.scanResultStatus"
                    StringEquals = "NO_THREATS_FOUND"
                    Next         = "ValidateFileTask"
                  }
                ]
                Default = "DeleteThreatStagingObject"
              }

              ValidateFileTask = {
                Type       = "Task"
                Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
                OutputPath = "$.Payload"
                Parameters = {
                  FunctionName = module.validate_file.arn
                  "Payload.$"  = "$"
                }
                Retry = local.lambda_retry
                Next  = "IsFileValid"
              }

              IsFileValid = {
                Type = "Choice"
                Choices = [
                  {
                    Variable      = "$.isValid"
                    BooleanEquals = true
                    Next          = "ResolveFinalKeyTask"
                  }
                ]
                Default = "DeleteInvalidStagingObject"
              }

              ResolveFinalKeyTask = {
                Type       = "Task"
                Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
                OutputPath = "$.Payload"
                Parameters = {
                  FunctionName = module.resolve_final_key.arn
                  "Payload.$"  = "$"
                }
                Retry = local.lambda_retry
                Next  = "CopyToUploadBucket"
              }

              CopyToUploadBucket = {
                Type       = "Task"
                Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
                OutputPath = "$.Payload"
                Parameters = {
                  FunctionName = module.copy_to_upload_bucket.arn
                  "Payload.$"  = "$"
                }
                Retry = local.lambda_retry
                Next  = "TransformAndDeleteStagingFile"
              }

              TransformAndDeleteStagingFile = {
                Type       = "Parallel"
                OutputPath = "$[0]"
                Branches = [
                  {
                    StartAt = "IsImage"
                    States = {
                      IsImage = {
                        Type = "Choice"
                        Choices = [
                          {
                            Variable      = "$.mime"
                            StringMatches = "image/*"
                            Next          = "TransformImageTask"
                          }
                        ]
                        Default = "SkipTransformForNonImage"
                      }

                      TransformImageTask = {
                        Type       = "Task"
                        Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
                        OutputPath = "$.Payload"
                        Parameters = {
                          FunctionName = module.transform_image.arn
                          "Payload.$"  = "$"
                        }
                        Retry = local.lambda_retry
                        Next  = "AddMetadataTask"
                      }

                      SkipTransformForNonImage = {
                        Type = "Pass"
                        Next = "AddMetadataTask"
                      }

                      AddMetadataTask = {
                        Type       = "Task"
                        Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
                        OutputPath = "$.Payload"
                        Parameters = {
                          FunctionName = module.add_metadata.arn
                          "Payload.$"  = "$"
                        }
                        Retry = local.lambda_retry
                        End   = true
                      }
                    }
                  },
                  {
                    StartAt = "DeleteStagingObjectOnCopySuccess"
                    States = {
                      DeleteStagingObjectOnCopySuccess = {
                        Type     = "Task"
                        Resource = "arn:${data.aws_partition.current.partition}:states:::aws-sdk:s3:deleteObject"
                        Parameters = {
                          Bucket  = var.staging_bucket_id
                          "Key.$" = "$.key"
                        }
                        ResultPath = null
                        Retry      = local.s3_retry
                        End        = true
                      }
                    }
                  }
                ]
                End = true
              }

              DeleteInvalidStagingObject = {
                Type     = "Task"
                Resource = "arn:${data.aws_partition.current.partition}:states:::aws-sdk:s3:deleteObject"
                Parameters = {
                  Bucket  = var.staging_bucket_id
                  "Key.$" = "$.key"
                }
                ResultPath = null
                Retry      = local.s3_retry
                Next       = "MarkValidationFailed"
              }

              MarkValidationFailed = {
                Type = "Pass"
                Result = {
                  isSuccess = false
                  name      = "VALIDATION_FAILED"
                  message   = "File rejected due to invalid content"
                }
                ResultPath = "$.handledStatus"
                End        = true
              }

              DeleteThreatStagingObject = {
                Type     = "Task"
                Resource = "arn:${data.aws_partition.current.partition}:states:::aws-sdk:s3:deleteObject"
                Parameters = {
                  Bucket  = var.staging_bucket_id
                  "Key.$" = "$.key"
                }
                ResultPath = null
                Retry      = local.s3_retry
                Next       = "MarkThreatDetected"
              }

              MarkThreatDetected = {
                Type = "Pass"
                Result = {
                  isSuccess = false
                  name      = "THREAT_DETECTED"
                  message   = "File rejected due to malware scan result"
                }
                ResultPath = "$.handledStatus"
                End        = true
              }
            }
          }
        ]
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "UpdateUploadStatusFailureTask"
          }
        ]
        Next = "UpdateUploadStatusSuccessTask"
      }

      UpdateUploadStatusSuccessTask = {
        Type       = "Task"
        Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        OutputPath = "$.Payload"
        Parameters = {
          FunctionName = module.update_upload_status.arn
          "Payload.$"  = "$"
        }
        Retry = local.lambda_retry
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "MarkStatusUpdateFailedOnSuccess"
          }
        ]
        Next = "ShouldCleanupReplacedUpload"
      }

      ShouldCleanupReplacedUpload = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.status.name"
            StringEquals = "UPLOAD_COMPLETE"
            Next         = "CleanupReplacedUploadTask"
          }
        ]
        Default = "SkipCleanupForNonCompleteStatus"
      }

      CleanupReplacedUploadTask = {
        Type       = "Task"
        Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        OutputPath = "$.Payload"
        Parameters = {
          FunctionName = module.cleanup_replaced_upload.arn
          "Payload.$"  = "$"
        }
        Retry = local.lambda_retry
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "MarkCleanupFailed"
          }
        ]
        Next = "UploadStatusEmitSuccess"
      }

      SkipCleanupForNonCompleteStatus = {
        Type = "Pass"
        Next = "UploadStatusEmitSuccess"
      }

      UploadStatusEmitSuccess = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              EventBusName = aws_cloudwatch_event_bus.file_processing.name
              DetailType   = "UploadStatusChanged"
              Source       = "com.file-processing.upload"
              "Detail.$"   = "$"
            }
          ]
        }
        ResultPath = "$.eventBridgeResult"
        Retry      = local.eventbridge_retry
        Next       = "IsWorkflowFailure"
      }

      IsWorkflowFailure = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.status.name"
            StringEquals = "UPLOAD_FAILED"
            Next         = "WorkflowFailureError"
          },
          {
            Variable     = "$.status.name"
            StringEquals = "CLEANUP_FAILED"
            Next         = "WorkflowFailureError"
          },
          {
            Variable     = "$.status.name"
            StringEquals = "STATUS_UPDATE_FAILED"
            Next         = "WorkflowFailureError"
          }
        ]
        Default = "FileUploadSuccess"
      }

      FileUploadSuccess = {
        Type = "Succeed"
      }

      WorkflowFailureError = {
        Type      = "Fail"
        ErrorPath = "$.status.name"
        CausePath = "$.status.message"
      }

      UpdateUploadStatusFailureTask = {
        Type       = "Task"
        Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        OutputPath = "$.Payload"
        Parameters = {
          FunctionName = module.update_upload_status.arn
          "Payload.$"  = "$"
        }
        Retry = local.lambda_retry
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            ResultPath  = "$.error"
            Next        = "MarkStatusUpdateFailedOnFailure"
          }
        ]
        Next = "UploadStatusEmitFailureOnCatch"
      }

      UploadStatusEmitFailureOnCatch = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              EventBusName = aws_cloudwatch_event_bus.file_processing.name
              DetailType   = "UploadStatusChanged"
              Source       = "com.file-processing.upload"
              "Detail.$"   = "$"
            }
          ]
        }
        ResultPath = "$.eventBridgeResult"
        Retry      = local.eventbridge_retry
        Next       = "WorkflowFailureError"
      }

      MarkCleanupFailed = {
        Type = "Pass"
        Result = {
          isSuccess = false
          name      = "CLEANUP_FAILED"
          message   = "File processed but cleanup of the replaced upload failed"
        }
        ResultPath = "$.handledStatus"
        Next       = "UpdateUploadStatusCleanupFailureTask"
      }

      UpdateUploadStatusCleanupFailureTask = {
        Type       = "Task"
        Resource   = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        OutputPath = "$.Payload"
        Parameters = {
          FunctionName = module.update_upload_status.arn
          "Payload.$"  = "$"
        }
        Retry = local.lambda_retry
        Next  = "UploadStatusEmitFailureOnCleanup"
      }

      UploadStatusEmitFailureOnCleanup = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              EventBusName = aws_cloudwatch_event_bus.file_processing.name
              DetailType   = "UploadStatusChanged"
              Source       = "com.file-processing.upload"
              "Detail.$"   = "$"
            }
          ]
        }
        ResultPath = "$.eventBridgeResult"
        Retry      = local.eventbridge_retry
        Next       = "WorkflowFailureError"
      }

      MarkStatusUpdateFailedOnSuccess = {
        Type = "Pass"
        Result = {
          isSuccess = false
          name      = "STATUS_UPDATE_FAILED"
          message   = "Failed to persist the upload status"
        }
        ResultPath = "$.handledStatus"
        Next       = "EmitStatusUpdateFailedOnSuccess"
      }

      EmitStatusUpdateFailedOnSuccess = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              EventBusName = aws_cloudwatch_event_bus.file_processing.name
              DetailType   = "UploadStatusChanged"
              Source       = "com.file-processing.upload"
              "Detail.$"   = "$"
            }
          ]
        }
        Retry = local.eventbridge_retry
        Next  = "FailStatusUpdateFailedOnSuccess"
      }

      FailStatusUpdateFailedOnSuccess = {
        Type      = "Fail"
        ErrorPath = "$.handledStatus.name"
        CausePath = "$.handledStatus.message"
      }

      MarkStatusUpdateFailedOnFailure = {
        Type = "Pass"
        Result = {
          isSuccess = false
          name      = "STATUS_UPDATE_FAILED"
          message   = "Failed to persist the upload status"
        }
        ResultPath = "$.handledStatus"
        Next       = "EmitStatusUpdateFailedOnFailure"
      }

      EmitStatusUpdateFailedOnFailure = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::events:putEvents"
        Parameters = {
          Entries = [
            {
              EventBusName = aws_cloudwatch_event_bus.file_processing.name
              DetailType   = "UploadStatusChanged"
              Source       = "com.file-processing.upload"
              "Detail.$"   = "$"
            }
          ]
        }
        Retry = local.eventbridge_retry
        Next  = "FailStatusUpdateFailedOnFailure"
      }

      FailStatusUpdateFailedOnFailure = {
        Type      = "Fail"
        ErrorPath = "$.handledStatus.name"
        CausePath = "$.handledStatus.message"
      }
    }
  })
}

resource "aws_cloudwatch_event_bus" "file_processing" {
  name = "${var.resource_prefix}-events"

  tags = {
    Name = "${var.resource_prefix}-events"
  }
}

resource "aws_cloudwatch_log_group" "state_machine" {
  name              = "/aws/vendedlogs/states/${var.resource_prefix}-file-upload"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.resource_prefix}-file-upload"
  }
}

resource "aws_sfn_state_machine" "file_upload" {
  name       = "${var.resource_prefix}-file-upload"
  role_arn   = aws_iam_role.state_machine.arn
  type       = "EXPRESS"
  definition = local.state_machine_definition

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.state_machine.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = {
    Name = "${var.resource_prefix}-file-upload"
  }

  depends_on = [aws_iam_role_policy.state_machine]
}
