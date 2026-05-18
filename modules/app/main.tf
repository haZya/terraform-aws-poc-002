data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix      = "${var.app_name}-${var.environment}"
  safe_name_prefix = replace(lower(local.name_prefix), "/[^a-z0-9-]/", "-")
  resource_prefix  = substr(local.safe_name_prefix, 0, 40)
  bucket_prefix    = substr(local.safe_name_prefix, 0, 28)

  s3_files_bucket_name = "${local.bucket_prefix}-${data.aws_region.current.id}-${data.aws_caller_identity.current.account_id}-files"
}

module "network" {
  source = "../network"

  resource_prefix = local.resource_prefix
  vpc_cidr        = var.vpc_cidr
  max_azs         = var.max_azs
}

module "s3_files" {
  source = "../s3-files"

  resource_prefix          = local.resource_prefix
  bucket_name              = local.s3_files_bucket_name
  force_destroy_data       = var.force_destroy_data
  vpc_id                   = module.network.vpc_id
  vpc_cidr                 = module.network.vpc_cidr_block
  private_subnet_ids_by_az = module.network.private_subnet_ids_by_az
  wordpress_posix_uid      = var.wordpress_posix_uid
  wordpress_posix_gid      = var.wordpress_posix_gid
}

module "database" {
  source = "../database"

  resource_prefix            = local.resource_prefix
  vpc_id                     = module.network.vpc_id
  isolated_subnet_ids        = module.network.isolated_subnet_ids
  db_name                    = var.db_name
  db_master_username         = var.db_master_username
  db_port                    = var.db_port
  db_engine_version          = var.db_engine_version
  db_instance_class          = var.db_instance_class
  db_allocated_storage       = var.db_allocated_storage
  db_max_allocated_storage   = var.db_max_allocated_storage
  db_storage_type            = var.db_storage_type
  db_backup_retention_period = var.db_backup_retention_period
  db_deletion_protection     = var.db_deletion_protection
  db_skip_final_snapshot     = var.db_skip_final_snapshot
}

module "wordpress_image" {
  source = "../wordpress-image"

  resource_prefix          = local.resource_prefix
  force_destroy_data       = var.force_destroy_data
  aws_cli_profile          = var.aws_cli_profile
  mirror_wordpress_image   = var.mirror_wordpress_image
  wordpress_source_image   = var.wordpress_source_image
  wordpress_image_tag      = var.wordpress_image_tag
  wordpress_image_platform = var.wordpress_image_platform
}

module "wordpress_service" {
  source = "../wordpress-service"

  resource_prefix            = local.resource_prefix
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  private_subnet_ids         = module.network.private_subnet_ids
  wordpress_image            = module.wordpress_image.image_uri
  wordpress_desired_count    = var.wordpress_desired_count
  wordpress_cpu              = var.wordpress_cpu
  wordpress_memory           = var.wordpress_memory
  wordpress_container_port   = var.wordpress_container_port
  wordpress_admin_username   = var.wordpress_admin_username
  wordpress_admin_password   = var.wordpress_admin_password
  wordpress_admin_email      = var.wordpress_admin_email
  wordpress_blog_name        = var.wordpress_blog_name
  db_name                    = var.db_name
  db_port                    = var.db_port
  database_address           = module.database.address
  database_secret_arn        = module.database.secret_arn
  database_security_group_id = module.database.security_group_id
  s3_files_bucket_arn        = module.s3_files.bucket_arn
  s3_files_file_system_arn   = module.s3_files.file_system_arn
  s3_files_access_point_arn  = module.s3_files.access_point_arn
  log_retention_days         = var.log_retention_days
  enable_container_insights  = var.enable_container_insights

  depends_on = [
    module.s3_files,
    module.wordpress_image,
  ]
}
