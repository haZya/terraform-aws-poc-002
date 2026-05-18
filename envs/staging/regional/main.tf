module "app" {
  source = "../../../modules/app"

  app_name    = local.app_name
  environment = local.environment
}
