locals {
  app_name           = "poc-002"
  github_environment = "staging"
  state_bucket_name  = var.state_bucket_name != null ? var.state_bucket_name : "${local.app_name}-terraform-state-${var.state_account_id}"
  state_key_prefix   = "${local.app_name}/staging"
}
