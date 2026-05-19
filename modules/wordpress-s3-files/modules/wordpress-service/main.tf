data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  load_balancer_name = "${substr(var.resource_prefix, 0, 21)}-wordpress"
}

resource "aws_cloudwatch_log_group" "wordpress" {
  name              = "/ecs/${var.resource_prefix}-wordpress"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.resource_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.resource_prefix}-ecs-execution"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.database_secret_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name   = "${var.resource_prefix}-ecs-secrets"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets.json
}

resource "aws_iam_role" "ecs_task" {
  name               = "${var.resource_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json

  tags = {
    Name = "${var.resource_prefix}-ecs-task"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_files" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonS3FilesClientReadWriteAccess"
}

data "aws_iam_policy_document" "ecs_task_s3" {
  statement {
    sid = "S3ObjectReadAccess"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["${var.s3_files_bucket_arn}/*"]
  }

  statement {
    sid       = "S3BucketListAccess"
    actions   = ["s3:ListBucket"]
    resources = [var.s3_files_bucket_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  name   = "${var.resource_prefix}-ecs-s3-files"
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task_s3.json
}

resource "aws_ecs_cluster" "wordpress" {
  name = "${var.resource_prefix}-wordpress"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.resource_prefix}-alb"
  description = "WordPress load balancer security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.resource_prefix}-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "ecs_service" {
  name        = "${var.resource_prefix}-ecs-service"
  description = "WordPress ECS service security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.resource_prefix}-ecs-service"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_service_http" {
  security_group_id            = aws_security_group.ecs_service.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.wordpress_container_port
  ip_protocol                  = "tcp"
  to_port                      = var.wordpress_container_port
}

resource "aws_vpc_security_group_egress_rule" "ecs_service_all" {
  security_group_id = aws_security_group.ecs_service.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "database_from_ecs" {
  security_group_id            = var.database_security_group_id
  referenced_security_group_id = aws_security_group.ecs_service.id
  from_port                    = var.db_port
  ip_protocol                  = "tcp"
  to_port                      = var.db_port
}

resource "aws_lb" "wordpress" {
  name               = local.load_balancer_name
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }

  lifecycle {
    precondition {
      condition     = length(var.public_subnet_ids) >= 2
      error_message = "At least two public subnets are required for an internet-facing application load balancer."
    }
  }
}

resource "aws_lb_target_group" "wordpress" {
  name        = local.load_balancer_name
  port        = var.wordpress_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

resource "aws_ecs_task_definition" "wordpress" {
  family                   = "${var.resource_prefix}-wordpress"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.wordpress_cpu
  memory                   = var.wordpress_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "wordpress"
      image     = var.wordpress_image
      essential = true
      portMappings = [
        {
          containerPort = var.wordpress_container_port
          hostPort      = var.wordpress_container_port
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "s3files"
          containerPath = "/bitnami/wordpress"
          readOnly      = false
        }
      ]
      environment = [
        {
          name  = "WORDPRESS_DATABASE_HOST"
          value = var.database_address
        },
        {
          name  = "WORDPRESS_DATABASE_NAME"
          value = var.db_name
        },
        {
          name  = "WORDPRESS_DATABASE_PORT_NUMBER"
          value = tostring(var.db_port)
        },
        {
          name  = "WORDPRESS_ENABLE_DATABASE_SSL"
          value = "yes"
        },
        {
          name  = "WORDPRESS_VERIFY_DATABASE_SSL"
          value = "no"
        },
        {
          name  = "MYSQL_CLIENT_ENABLE_SSL"
          value = "yes"
        },
        {
          name  = "WORDPRESS_USERNAME"
          value = var.wordpress_admin_username
        },
        {
          name  = "WORDPRESS_PASSWORD"
          value = var.wordpress_admin_password
        },
        {
          name  = "WORDPRESS_EMAIL"
          value = var.wordpress_admin_email
        },
        {
          name  = "WORDPRESS_BLOG_NAME"
          value = var.wordpress_blog_name
        }
      ]
      secrets = [
        {
          name      = "WORDPRESS_DATABASE_USER"
          valueFrom = "${var.database_secret_arn}:username::"
        },
        {
          name      = "WORDPRESS_DATABASE_PASSWORD"
          valueFrom = "${var.database_secret_arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.wordpress.name
          awslogs-region        = data.aws_region.current.id
          awslogs-stream-prefix = "wordpress"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "s3files"

    s3files_volume_configuration {
      access_point_arn = var.s3_files_access_point_arn
      file_system_arn  = var.s3_files_file_system_arn
      root_directory   = "/"
    }
  }

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }

  depends_on = [
    aws_iam_role_policy.ecs_task_execution_secrets,
    aws_iam_role_policy.ecs_task_s3,
    aws_iam_role_policy_attachment.ecs_task_execution,
    aws_iam_role_policy_attachment.ecs_task_s3_files,
  ]
}

resource "aws_ecs_service" "wordpress" {
  name                               = "${var.resource_prefix}-wordpress"
  cluster                            = aws_ecs_cluster.wordpress.id
  task_definition                    = aws_ecs_task_definition.wordpress.arn
  desired_count                      = var.wordpress_desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 300

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress.arn
    container_name   = "wordpress"
    container_port   = var.wordpress_container_port
  }

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }

  depends_on = [aws_lb_listener.http]
}
