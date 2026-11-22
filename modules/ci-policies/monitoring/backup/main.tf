data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  prefix     = "${var.name_root}-${var.project}"
  backup     = "arn:aws:backup:${local.region}:${local.account_id}"

  # Write-only: pair it with monitoring/read, which the apply role also needs
  # for refresh. The snapshots role itself is created with monitoring/node.
  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageTheVault"
        Effect = "Allow"
        Action = [
          "backup:CreateBackupVault",
          "backup:DeleteBackupVault",
          "backup:TagResource",
          "backup:UntagResource",
        ]
        Resource = "${local.backup}:backup-vault:${local.prefix}-snapshots"
      },
      {
        # A backup plan's ARN holds a random ID, not its name, and its
        # selections are authorized against the plan, so neither can be
        # scoped to <prefix>-snapshots: any plan in the region.
        Sid    = "ManageThePlan"
        Effect = "Allow"
        Action = [
          "backup:CreateBackupPlan",
          "backup:UpdateBackupPlan",
          "backup:DeleteBackupPlan",
          "backup:CreateBackupSelection",
          "backup:DeleteBackupSelection",
          "backup:TagResource",
          "backup:UntagResource",
        ]
        Resource = "${local.backup}:backup-plan:*"
      },
      {
        # Gap: CreateBackupVault mounts the vault's storage, and
        # backup-storage:MountCapsule has no resource-level support. It
        # grants nothing outside a vault create.
        Sid      = "MountTheVaultStorage"
        Effect   = "Allow"
        Action   = "backup-storage:MountCapsule"
        Resource = "*"
      },
      {
        # The vault's default key (aws/backup), whose ID is random: only
        # through AWS Backup in this region, never directly.
        Sid    = "UseTheVaultKeyThroughBackup"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:DescribeKey",
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:RetireGrant",
        ]
        Resource  = "arn:aws:kms:${local.region}:${local.account_id}:key/*"
        Condition = { StringEquals = { "kms:ViaService" = "backup.${local.region}.amazonaws.com" } }
      },
      {
        # The role the selection's backups run as, and only to AWS Backup.
        Sid       = "PassTheSnapshotsRole"
        Effect    = "Allow"
        Action    = "iam:PassRole"
        Resource  = "arn:aws:iam::${local.account_id}:role/${local.prefix}-snapshots"
        Condition = { StringEquals = { "iam:PassedToService" = "backup.amazonaws.com" } }
      },
    ]
  }
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = "CI policy monitoring/backup: manage the monitoring node's snapshot vault, plan and selection, and pass the snapshots role to AWS Backup"
  policy      = jsonencode(local.policy)

  tags = {
    Component = "ci"
  }
}
