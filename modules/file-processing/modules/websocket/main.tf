data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

resource "aws_dynamodb_table" "connections" {
  name             = "${var.resource_prefix}-websocket-connections"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "PK"
  range_key        = "SK"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "${var.resource_prefix}-websocket-connections"
  }
}

data "aws_iam_policy_document" "connection_handler" {
  statement {
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [aws_dynamodb_table.connections.arn]
  }
}

module "authorizer_lambda" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-websocket-authorizer"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/websocket/authorizer.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
}

module "connection_lambda" {
  source = "../lambda-function"

  function_name      = "${var.resource_prefix}-websocket-handler"
  source_dir         = var.lambda_source_dir
  entry              = "lambda/websocket/connection.ts"
  runtime            = var.lambda_runtime
  architectures      = var.lambda_architectures
  log_retention_days = var.log_retention_days
  policy_json        = data.aws_iam_policy_document.connection_handler.json
  environment = {
    CONNECTIONS_TABLE_NAME = aws_dynamodb_table.connections.name
  }
}

resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.resource_prefix}-websocket"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_authorizer" "websocket" {
  api_id                            = aws_apigatewayv2_api.websocket.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = module.authorizer_lambda.invoke_arn
  name                              = "${var.resource_prefix}-websocket-authorizer"
  authorizer_payload_format_version = "1.0"
  identity_sources = [
    "route.request.header.Authorization",
    "route.request.querystring.token",
  ]
}

resource "aws_apigatewayv2_integration" "connection" {
  api_id                 = aws_apigatewayv2_api.websocket.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = module.connection_lambda.invoke_arn
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "connect" {
  api_id             = aws_apigatewayv2_api.websocket.id
  route_key          = "$connect"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.websocket.id
  target             = "integrations/${aws_apigatewayv2_integration.connection.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.connection.id}"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.connection.id}"
}

resource "aws_apigatewayv2_route" "message" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "message"
  target    = "integrations/${aws_apigatewayv2_integration.connection.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.websocket.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_authorizer" {
  statement_id  = "AllowExecutionFromWebSocketAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = module.authorizer_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*"
}

resource "aws_lambda_permission" "allow_connection" {
  statement_id  = "AllowExecutionFromWebSocketApi"
  action        = "lambda:InvokeFunction"
  function_name = module.connection_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
}
