data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "db_cred_v1"
}

locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}


# Create Database Subnet Group
# terraform aws db subnet group
resource "aws_db_subnet_group" "this" {
  name        = "database subnets"
  subnet_ids  = [aws_subnet.private_ap_southeast_1a.id, aws_subnet.private_ap_southeast_1b.id]
  description = "Subnets for Database Instance"

  tags = {
    Name = "Database Subnets"
  }
}


# Create Database Instance Restored from DB Snapshots
# terraform aws db instance
resource "aws_db_instance" "database-instance" {

  skip_final_snapshot = true
  engine              = "mysql"
  engine_version      = "5.7"
  instance_class      = var.instance_class
  allocated_storage   = 10
  //iops                = 100

  db_subnet_group_name   = aws_db_subnet_group.this.name
  multi_az               = var.multi-az-deployment
  vpc_security_group_ids = [aws_security_group.that.id]
  publicly_accessible    = false
  username               = var.username
  password               = var.password
}


locals {
  cluster_identifier  = "${var.env}-${var.name}-db"
  engine_version_list = split(".", var.engine_version)
  major_version       = element(local.engine_version_list, 0)
  minor_version       = element(local.engine_version_list, 1)
}

resource "aws_security_group" "that" {
  name        = "${local.cluster_identifier}-sg"
  description = "Allow Inbound traffic from Security Groups and CIDRs"
  vpc_id      = aws_vpc.main.id
}

resource "aws_security_group_rule" "ingress_cidr_blocks" {
  count             = length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  description       = "Allow inbound traffic from existing CIDR blocks"
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = aws_security_group.that.id
}

resource "aws_security_group_rule" "ingress_groups" {
  #count                    = length(var.inbound_security_groups) > 0 ? length(var.inbound_security_groups) : 0
  description              = "Allow inbound traffic from Security Groups"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.that.id
  security_group_id        = aws_security_group.that.id
}




# Create an IAM role to allow enhanced monitoring
data "aws_iam_policy_document" "rds_enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name_prefix        = "rds-enhanced-monitoring-"
  assume_role_policy = data.aws_iam_policy_document.rds_enhanced_monitoring.json
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_rds_cluster" "this" {
  #checkov:skip=CKV2_AWS_27: Query Logging is not required
  #checkov:skip=CKV2_AWS_8: Backup is not required
  cluster_identifier                  = local.cluster_identifier
  database_name                       = "mysql"
  port                                = var.port
  backup_retention_period             = var.backup_retention_period
  skip_final_snapshot                 = true
  apply_immediately                   = true
  storage_encrypted                   = true
  vpc_security_group_ids              = [aws_security_group.that.id]
  preferred_maintenance_window        = var.preferred_maintenance_window
  db_subnet_group_name                = aws_db_subnet_group.this.name
  master_username                     = var.master_username
  master_password                     = var.master_password
  iam_database_authentication_enabled = true
  engine                              = "mysql"
  engine_version                      = var.engine_version
  engine_mode                         = "provisioned"
  deletion_protection                 = true

  depends_on = [
    aws_security_group.that,
    aws_db_subnet_group.this
  ]
}

resource "aws_rds_cluster_instance" "this" {
  #checkov:skip=CKV_AWS_118: Enhanced monitoring is not required
  count                        = var.instance_count
  identifier                   = "${local.cluster_identifier}-${count.index}"
  cluster_identifier           = aws_rds_cluster.this.id
  instance_class               = var.instance_class
  db_subnet_group_name         = aws_db_subnet_group.this.name
  publicly_accessible          = false
  engine                       = aws_rds_cluster.this.engine
  engine_version               = aws_rds_cluster.this.engine_version
  preferred_maintenance_window = var.preferred_maintenance_window
  auto_minor_version_upgrade   = var.auto_minor_version_upgrade
  performance_insights_enabled = true
  apply_immediately            = false
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn          = var.monitoring_interval > 0 ? aws_iam_role.rds_enhanced_monitoring[0].arn : null

  depends_on = [
    aws_rds_cluster.this,
    aws_db_subnet_group.this,
    aws_iam_role.rds_enhanced_monitoring
  ]

  lifecycle {
    ignore_changes = [engine_version]
  }
}




resource "aws_ssm_parameter" "writer" {
  #checkov:skip=CKV2_AWS_34: "AWS SSM Parameter should be Encrypted"
  name        = "/project/${var.env}/${var.name}/aurora/write"
  description = "Cluster read-write endpoint"
  type        = "String"
  value       = aws_rds_cluster.this.endpoint
}

resource "aws_ssm_parameter" "reader" {
  #checkov:skip=CKV2_AWS_34: "AWS SSM Parameter should be Encrypted"
  name        = "/project/${var.env}/${var.name}/aurora/read"
  description = "Cluster read-only endpoint"
  type        = "String"
  value       = aws_rds_cluster.this.reader_endpoint
}




