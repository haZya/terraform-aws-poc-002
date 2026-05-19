module "wordpress_s3_files" {
  source = "../../../modules/wordpress-s3-files"

  app_name    = local.app_name
  environment = local.environment
}

module "file_processing" {
  source = "../../../modules/file-processing"

  app_name    = local.app_name
  environment = local.environment
}
