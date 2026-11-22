mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
}

variables {
  name      = "jaws-monitoring-ci-apply-monitoring-backup"
  name_root = "jaws"
  project   = "monitoring"
}

run "monitoring_backup_grants_exactly_these_statements" {
  command = plan

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheVault"])) == jsonencode({
      Sid    = "ManageTheVault"
      Effect = "Allow"
      Action = [
        "backup:CreateBackupVault",
        "backup:DeleteBackupVault",
        "backup:TagResource",
        "backup:UntagResource",
      ]
      Resource = "arn:aws:backup:us-east-1:123456789012:backup-vault:jaws-monitoring-snapshots"
    })
    error_message = "the snapshot vault, by name"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageThePlan"])) == jsonencode({
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
      Resource = "arn:aws:backup:us-east-1:123456789012:backup-plan:*"
    })
    error_message = "the plan and its selection; a plan's ARN holds a random ID, not its name"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "MountTheVaultStorage"])) == jsonencode({
      Sid      = "MountTheVaultStorage"
      Effect   = "Allow"
      Action   = "backup-storage:MountCapsule"
      Resource = "*"
    })
    error_message = "CreateBackupVault needs backup-storage:MountCapsule, which takes no resource: a documented gap"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "UseTheVaultKeyThroughBackup"])) == jsonencode({
      Sid    = "UseTheVaultKeyThroughBackup"
      Effect = "Allow"
      Action = [
        "kms:CreateGrant",
        "kms:DescribeKey",
        "kms:GenerateDataKey",
        "kms:Decrypt",
        "kms:RetireGrant",
      ]
      Resource  = "arn:aws:kms:us-east-1:123456789012:key/*"
      Condition = { StringEquals = { "kms:ViaService" = "backup.us-east-1.amazonaws.com" } }
    })
    error_message = "the vault's default key, only through AWS Backup"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "PassTheSnapshotsRole"])) == jsonencode({
      Sid       = "PassTheSnapshotsRole"
      Effect    = "Allow"
      Action    = "iam:PassRole"
      Resource  = "arn:aws:iam::123456789012:role/jaws-monitoring-snapshots"
      Condition = { StringEquals = { "iam:PassedToService" = "backup.amazonaws.com" } }
    })
    error_message = "only the snapshots role, and only to AWS Backup"
  }
}

run "monitoring_backup_grants_nothing_else" {
  command = plan

  assert {
    condition = jsonencode(sort([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid])) == jsonencode(sort([
      "ManageTheVault",
      "ManageThePlan",
      "MountTheVaultStorage",
      "UseTheVaultKeyThroughBackup",
      "PassTheSnapshotsRole",
    ]))
    error_message = "monitoring/backup is exactly these statements"
  }

  assert {
    condition     = jsonencode([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid if contains(tolist(flatten([s.Resource])), "*")]) == jsonencode(["MountTheVaultStorage"])
    error_message = "only the documented gap may use Resource = *"
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.this.policy).Statement :
      try(s.Condition.StringEquals["iam:PassedToService"], null) != null if contains(tolist(flatten([s.Action])), "iam:PassRole")
    ])
    error_message = "every iam:PassRole names the service it passes to"
  }

  assert {
    condition = jsonencode([
      for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) :
      a if can(regex("^[a-z0-9-]+:(Describe|Get|List)", a))
    ]) == jsonencode(["kms:DescribeKey"])
    error_message = "a write policy grants no reads but the key lookup CreateBackupVault makes through AWS Backup; monitoring/read has the rest"
  }
}

# `description` forces replacement of the policy, which would detach it from
# every role mid-apply. It is frozen; change the README instead.
run "description_is_frozen" {
  command = plan

  assert {
    condition     = aws_iam_policy.this.description == "CI policy monitoring/backup: manage the monitoring node's snapshot vault, plan and selection, and pass the snapshots role to AWS Backup"
    error_message = "the policy description must never change: it forces replacement"
  }
}

run "fits_the_managed_policy_size_limit" {
  command = plan

  assert {
    condition     = length(aws_iam_policy.this.policy) <= 6144
    error_message = "managed policies are limited to 6,144 characters"
  }
}
