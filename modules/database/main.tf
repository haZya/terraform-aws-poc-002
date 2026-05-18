resource "aws_db_subnet_group" "wordpress" {
  name       = "${var.resource_prefix}-wordpress"
  subnet_ids = var.isolated_subnet_ids

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }
}

resource "aws_security_group" "database" {
  name        = "${var.resource_prefix}-db"
  description = "WordPress database security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.resource_prefix}-db"
  }
}

resource "aws_db_instance" "wordpress" {
  identifier                  = "${var.resource_prefix}-wordpress"
  allocated_storage           = var.db_allocated_storage
  max_allocated_storage       = var.db_max_allocated_storage
  storage_type                = var.db_storage_type
  storage_encrypted           = true
  engine                      = "mariadb"
  engine_version              = var.db_engine_version
  instance_class              = var.db_instance_class
  db_name                     = var.db_name
  username                    = var.db_master_username
  manage_master_user_password = true
  port                        = var.db_port
  db_subnet_group_name        = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids      = [aws_security_group.database.id]
  publicly_accessible         = false
  backup_retention_period     = var.db_backup_retention_period
  delete_automated_backups    = true
  deletion_protection         = var.db_deletion_protection
  skip_final_snapshot         = var.db_skip_final_snapshot
  apply_immediately           = true

  tags = {
    Name = "${var.resource_prefix}-wordpress"
  }
}
