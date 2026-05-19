locals {
  source_files = fileset(var.source_dir, "lambda/**/*.ts")
  source_hash = base64sha256(jsonencode({
    entry         = var.entry
    include_sharp = var.include_sharp
    files         = { for file in local.source_files : file => filesha256("${var.source_dir}/${file}") }
    package       = filesha256("${var.source_dir}/package.json")
    package_lock  = fileexists("${var.source_dir}/package-lock.json") ? filesha256("${var.source_dir}/package-lock.json") : "none"
    build_script  = filesha256("${path.module}/build-lambda.mjs")
  }))
  build_dir   = "${path.root}/.terraform/build/file-processing"
  output_zip  = "${local.build_dir}/${var.function_name}.zip"
  script_path = replace("${path.module}/build-lambda.mjs", "\\", "/")
  source_dir  = replace(var.source_dir, "\\", "/")
  output_path = replace(local.output_zip, "\\", "/")
}

data "aws_partition" "current" {}

resource "terraform_data" "bundle" {
  triggers_replace = {
    source_hash = local.source_hash
  }

  provisioner "local-exec" {
    command = "node \"${local.script_path}\" --project \"${local.source_dir}\" --entry \"${var.entry}\" --output \"${local.output_path}\"${var.include_sharp ? " --include-sharp" : ""}"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${var.function_name}-role"
  }
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "custom" {
  count = length(var.policy_jsons)

  name   = length(var.policy_jsons) == 1 ? "${var.function_name}-policy" : "${var.function_name}-policy-${count.index}"
  role   = aws_iam_role.lambda.id
  policy = var.policy_jsons[count.index]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = var.function_name
  }
}

resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = aws_iam_role.lambda.arn
  runtime          = var.runtime
  architectures    = var.architectures
  handler          = "index.handler"
  filename         = local.output_zip
  source_code_hash = local.source_hash
  timeout          = var.timeout
  memory_size      = var.memory_size

  dynamic "environment" {
    for_each = length(var.environment) == 0 ? [] : [1]

    content {
      variables = var.environment
    }
  }

  tags = {
    Name = var.function_name
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.basic_execution,
    aws_iam_role_policy.custom,
    terraform_data.bundle,
  ]
}
