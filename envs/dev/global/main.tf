module "file_processing_global" {
  source = "../../../modules/file-processing-global"

  app_name    = local.app_name
  environment = local.environment
}
