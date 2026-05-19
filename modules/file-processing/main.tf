data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix         = "${var.app_name}-${var.environment}-file-processing"
  safe_name_prefix    = replace(lower(local.name_prefix), "/[^a-z0-9-]/", "-")
  resource_prefix     = substr(local.safe_name_prefix, 0, 40)
  bucket_prefix       = substr(local.safe_name_prefix, 0, 20)
  lambda_source_dir   = var.lambda_source_dir == null ? abspath(path.module) : abspath(var.lambda_source_dir)
  lambda_source_arg   = replace(local.lambda_source_dir, "\\", "/")
  install_deps_script = replace("${path.module}/modules/lambda-function/install-deps.mjs", "\\", "/")

  staging_bucket_name = "${local.bucket_prefix}-${data.aws_region.current.id}-${data.aws_caller_identity.current.account_id}-staging"
  upload_bucket_name  = "${local.bucket_prefix}-${data.aws_caller_identity.current.account_id}-uploads"
  upload_bucket_arn   = "arn:${data.aws_partition.current.partition}:s3:::${local.upload_bucket_name}"
}

resource "terraform_data" "lambda_dependencies" {
  count = var.install_lambda_dependencies ? 1 : 0

  triggers_replace = {
    package_json      = filesha256("${local.lambda_source_dir}/package.json")
    package_lock_json = fileexists("${local.lambda_source_dir}/package-lock.json") ? filesha256("${local.lambda_source_dir}/package-lock.json") : "none"
  }

  provisioner "local-exec" {
    command = "node \"${local.install_deps_script}\" --project \"${local.lambda_source_arg}\""
  }
}

module "storage" {
  source = "./modules/storage"

  resource_prefix     = local.resource_prefix
  staging_bucket_name = local.staging_bucket_name
  force_destroy_data  = var.force_destroy_data
}

module "database" {
  source = "./modules/database"

  resource_prefix = local.resource_prefix
}

module "guard_duty" {
  source = "./modules/guard-duty"

  resource_prefix    = local.resource_prefix
  staging_bucket_id  = module.storage.staging_bucket_id
  staging_bucket_arn = module.storage.staging_bucket_arn
}

module "websocket" {
  source = "./modules/websocket"

  resource_prefix      = local.resource_prefix
  lambda_source_dir    = local.lambda_source_dir
  lambda_runtime       = var.lambda_runtime
  lambda_architectures = var.lambda_architectures
  log_retention_days   = var.log_retention_days

  depends_on = [terraform_data.lambda_dependencies]
}

module "upload_processing" {
  source = "./modules/upload-processing"

  resource_prefix             = local.resource_prefix
  lambda_source_dir           = local.lambda_source_dir
  lambda_runtime              = var.lambda_runtime
  lambda_architectures        = var.lambda_architectures
  log_retention_days          = var.log_retention_days
  staging_bucket_id           = module.storage.staging_bucket_id
  staging_bucket_arn          = module.storage.staging_bucket_arn
  upload_bucket_id            = local.upload_bucket_name
  upload_bucket_arn           = local.upload_bucket_arn
  uploads_table_name          = module.database.uploads_table_name
  uploads_table_arn           = module.database.uploads_table_arn
  uploads_table_stream_arn    = module.database.uploads_table_stream_arn
  upload_relations_table_name = module.database.upload_relations_table_name
  upload_relations_table_arn  = module.database.upload_relations_table_arn
  connections_table_name      = module.websocket.connections_table_name
  connections_table_arn       = module.websocket.connections_table_arn
  websocket_api_id            = module.websocket.api_id
  websocket_api_execution_arn = module.websocket.api_execution_arn
  websocket_callback_url      = module.websocket.callback_url

  depends_on = [
    module.guard_duty,
    terraform_data.lambda_dependencies,
  ]
}
