module "register_upload" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-register-upload"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/register-upload.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.register_upload.json]
  environment = {
    UPLOADS_TABLE_NAME          = var.uploads_table_name
    UPLOAD_RELATIONS_TABLE_NAME = var.upload_relations_table_name
  }
}

module "generate_presigned_post" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-generate-presigned-post"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/generate-presigned-post.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.generate_presigned_post.json]
  environment = {
    UPLOADS_TABLE_NAME          = var.uploads_table_name
    UPLOAD_RELATIONS_TABLE_NAME = var.upload_relations_table_name
    STAGING_UPLOAD_BUCKET_NAME  = var.staging_bucket_id
  }
}

module "validate_file" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-validate-file"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/validate.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.validate_file.json]
  environment = {
    UPLOADS_TABLE_NAME          = var.uploads_table_name
    UPLOAD_RELATIONS_TABLE_NAME = var.upload_relations_table_name
  }
}

module "resolve_final_key" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-resolve-final-key"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/resolve-final-key.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
}

module "copy_to_upload_bucket" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-copy-to-upload"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/copy-to-upload-bucket.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.copy_to_upload_bucket.json]
  environment = {
    UPLOAD_BUCKET = var.upload_bucket_id
  }
}

module "transform_image" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-transform-image"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/transform-image.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.transform_image.json]
  timeout            = 20
  memory_size        = 512
  include_sharp      = true
  environment = {
    UPLOAD_BUCKET = var.upload_bucket_id
  }
}

module "add_metadata" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-add-metadata"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/add-metadata.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.add_metadata.json]
  environment = {
    UPLOADS_TABLE_NAME          = var.uploads_table_name
    UPLOAD_RELATIONS_TABLE_NAME = var.upload_relations_table_name
  }
}

module "update_upload_status" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-update-status"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/update-status.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.update_status.json]
  environment = {
    UPLOADS_TABLE_NAME          = var.uploads_table_name
    UPLOAD_RELATIONS_TABLE_NAME = var.upload_relations_table_name
  }
}

module "cleanup_replaced_upload" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-cleanup-replaced-upload"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/cleanup-replaced-upload.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.cleanup_replaced_upload.json]
  environment = {
    UPLOADS_TABLE_NAME          = var.uploads_table_name
    UPLOAD_RELATIONS_TABLE_NAME = var.upload_relations_table_name
    UPLOAD_BUCKET               = var.upload_bucket_id
  }
}

module "emit_upload_status" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-emit-upload-status"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/upload/emit-upload-status.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_jsons       = [data.aws_iam_policy_document.emit_upload_status.json]
  environment = {
    CONNECTIONS_TABLE_NAME = var.connections_table_name
    WEBSOCKET_API_ENDPOINT = var.websocket_callback_url
  }
}
