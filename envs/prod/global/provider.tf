provider "aws" {
  region              = var.region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      App         = local.app_name
      Environment = local.environment
      Region      = var.region
      Scope       = "global"
      ManagedBy   = "terraform"
    }
  }
}
