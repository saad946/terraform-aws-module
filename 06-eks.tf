locals {
  cluster_name = lower("${var.env}-${var.name}")
}

resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_58: "Ensure EKS Cluster has Secrets Encryption Enabled"
  name     = local.cluster_name
  role_arn = aws_iam_role.this.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.public_subnets
    endpoint_private_access = true
    endpoint_public_access  = false

    security_group_ids = [
      aws_security_group.this.id
    ]
  }
}


resource "aws_security_group" "this" {
  # Following pattern (env/account name)-(component)-(unique context)-(resource-type)
  name        = lower("${var.env}-eks-${var.name}-cluster-sg")
  vpc_id      = aws_vpc.main.id
  description = "EKS security group"
}

resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.this.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Outgoing traffic from EKS to the world"
}

resource "aws_security_group_rule" "ingress_443" {
  type              = "ingress"
  security_group_id = aws_security_group.this.id
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  # This range can be reduced in the future
  cidr_blocks = ["0.0.0.0/0"]
  description = "Incoming traffic to API server port"
}

data "aws_iam_policy_document" "this" {
  statement {
    sid = "EKSAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      identifiers = [
        "eks.amazonaws.com"
      ]

      type = "Service"
    }
  }
}

resource "aws_iam_role" "this" {
  # Following pattern system-(application)-(functionality)-role
  name                  = lower("system-eks-${local.cluster_name}-cluster-role")
  assume_role_policy    = data.aws_iam_policy_document.this.json
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.this.name
}

resource "aws_iam_role_policy_attachment" "service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.this.name
}

resource "aws_cloudwatch_log_group" "container_insights_application" {
  name              = "/aws/containerinsights/${local.cluster_name}/application"
  retention_in_days = var.container_insights_log_group_retention_days
}

resource "aws_cloudwatch_log_group" "container_insights_platform" {
  name              = "/aws/containerinsights/${local.cluster_name}/platform"
  retention_in_days = var.container_insights_log_group_retention_days
}

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/aws/containerinsights/${local.cluster_name}/prometheus"
  retention_in_days = var.container_insights_metrics_log_group_retention_days
}