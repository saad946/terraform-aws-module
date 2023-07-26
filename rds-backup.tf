/*data "aws_iam_policy_document" "rds_backup_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "rds_backup_service_role" {
  count = var.backup_enabled ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.rds_backup[0].name
}

resource "aws_iam_role_policy_attachment" "rds_backup_service_restore" {
  count = var.backup_enabled ? 1 : 0

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = aws_iam_role.rds_backup[0].name
}

resource "aws_iam_role" "rds_backup" {
  count = var.backup_enabled ? 1 : 0

  name               = "${local.cluster_identifier}-rds-backup"
  assume_role_policy = data.aws_iam_policy_document.rds_backup_assume_role.json
}

resource "aws_backup_selection" "rds_backup" {
  count = var.backup_enabled ? 1 : 0

  iam_role_arn = aws_iam_role.rds_backup[0].arn
  name         = "${local.cluster_identifier}-rds"
  plan_id      = aws_backup_plan.source_region[0].id

  resources = [
    aws_rds_cluster.this.arn
  ]
}

resource "aws_backup_vault" "source_region" {
  #checkov:skip=CKV_AWS_166: "Ensure Backup Vault is encrypted at rest using KMS CMK"
  count = var.backup_enabled ? 1 : 0

  name        = "${local.cluster_identifier}-rds-source"
  kms_key_arn = var.backup_vault_source_kms
}

resource "aws_backup_vault" "dest_region" {
  #checkov:skip=CKV_AWS_166: "Ensure Backup Vault is encrypted at rest using KMS CMK"
  count = var.backup_enabled ? 1 : 0

  name        = "${local.cluster_identifier}-rds-dest"
  kms_key_arn = var.backup_vault_dest_kms

  provider = aws.backup_provider
}

resource "aws_backup_plan" "source_region" {
  count = var.backup_enabled ? 1 : 0

  name = "${local.cluster_identifier}-rds"

  rule {
    rule_name         = "${local.cluster_identifier}-rds"
    target_vault_name = aws_backup_vault.source_region[0].name
    schedule          = var.backup_plan_schedule

    lifecycle {
      delete_after = var.backup_plan_delete_after
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dest_region[0].arn
    }
  }
}

*/
