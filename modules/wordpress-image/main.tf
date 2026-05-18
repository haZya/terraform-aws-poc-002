data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  ecr_registry        = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.${data.aws_partition.current.dns_suffix}"
  image_uri           = "${aws_ecr_repository.wordpress.repository_url}:${var.wordpress_image_tag}"
  aws_cli_profile_arg = var.aws_cli_profile == null ? "" : " --profile ${var.aws_cli_profile}"
}

resource "aws_ecr_repository" "wordpress" {
  name                 = "${var.resource_prefix}-wordpress"
  image_tag_mutability = "MUTABLE"
  force_delete         = var.force_destroy_data

  encryption_configuration {
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }
}

resource "terraform_data" "mirror_wordpress_image" {
  count = var.mirror_wordpress_image ? 1 : 0

  triggers_replace = {
    source_image      = var.wordpress_source_image
    destination_image = local.image_uri
    platform          = var.wordpress_image_platform
  }

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${data.aws_region.current.id}${local.aws_cli_profile_arg} | docker login --username AWS --password-stdin ${local.ecr_registry} && docker pull --platform ${var.wordpress_image_platform} ${var.wordpress_source_image} && docker tag ${var.wordpress_source_image} ${local.image_uri} && docker push ${local.image_uri}"
  }

  depends_on = [aws_ecr_repository.wordpress]
}
