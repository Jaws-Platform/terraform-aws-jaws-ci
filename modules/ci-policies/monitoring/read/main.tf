data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  prefix     = "${var.name_root}-${var.project}"

  config_bucket = "arn:aws:s3:::${local.prefix}-config-${local.account_id}"

  # With a zone only: the node's record is optional.
  zone_statements = [
    for s in [
      {
        Sid    = "ReadTheZone"
        Effect = "Allow"
        Action = [
          "route53:GetHostedZone",
          "route53:ListResourceRecordSets",
        ]
        Resource = "arn:aws:route53:::hostedzone/${coalesce(var.zone_id, "none")}"
      },
      {
        # Change IDs are random. Read-only status polling.
        Sid      = "ReadRoute53Changes"
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "arn:aws:route53:::change/*"
      },
    ] : s if var.zone_id != null
  ]

  # Read-only: pair it with the write leaves (monitoring/node, config,
  # functions and backup) on the apply role, for refresh.
  policy = {
    Version = "2012-10-17"
    Statement = concat([
      {
        # Gap: EC2 describe actions have no resource-level support. Covers the
        # instance (its attributes and credit specification), its volumes, the
        # security group and rules, the subnet and the AMI lookup.
        Sid      = "DescribeEc2"
        Effect   = "Allow"
        Action   = "ec2:Describe*"
        Resource = "*"
      },
      {
        # The node's own role and profile are named exactly <prefix>, outside
        # <prefix>-*.
        Sid    = "ReadTheRoles"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListRoleTags",
          "iam:GetInstanceProfile",
          "iam:ListInstanceProfileTags",
        ]
        Resource = [
          "arn:aws:iam::${local.account_id}:role/${local.prefix}",
          "arn:aws:iam::${local.account_id}:role/${local.prefix}-*",
          "arn:aws:iam::${local.account_id}:instance-profile/${local.prefix}",
        ]
      },
      {
        # The normalizer and the watchdog: configuration, code signing,
        # versions, the SNS permission and tags.
        Sid    = "ReadTheFunctions"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction*",
          "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:ListTags",
        ]
        Resource = "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.prefix}-*"
      },
      {
        Sid      = "ReadTheSchedules"
        Effect   = "Allow"
        Action   = "scheduler:GetSchedule"
        Resource = "arn:aws:scheduler:${local.region}:${local.account_id}:schedule/default/${local.prefix}-*"
      },
      {
        # Gap: no resource-level support. Lists log group names only.
        Sid      = "DescribeLogGroups"
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
      },
      {
        Sid      = "ReadTheLogGroups"
        Effect   = "Allow"
        Action   = "logs:ListTagsForResource"
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-*"
      },
      {
        # Gap: no resource-level support. Lists parameter names and types,
        # never values.
        Sid      = "DescribeParameters"
        Effect   = "Allow"
        Action   = "ssm:DescribeParameters"
        Resource = "*"
      },
      {
        # The node's parameters, /<prefix>/node/*. The owner's secrets live
        # elsewhere and are never read by Terraform.
        Sid    = "ReadTheParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:ListTagsForResource",
        ]
        Resource = "arn:aws:ssm:${local.region}:${local.account_id}:parameter/${local.prefix}/*"
      },
      {
        # Everything aws_s3_bucket and its configuration resources refresh.
        # ListBucketVersions: deleting a bundle in the versioned bucket lists
        # its versions first.
        Sid    = "ReadTheConfigBucket"
        Effect = "Allow"
        Action = [
          "s3:GetBucket*",
          "s3:GetEncryptionConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
          "s3:ListBucketVersions",
        ]
        Resource = local.config_bucket
      },
      {
        # The bundles: configuration, never secrets.
        Sid    = "ReadTheConfigObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectTagging",
        ]
        Resource = "${local.config_bucket}/*"
      },
      {
        # The vault by name. Backup plans (and the selections inside them)
        # are named by a random ID, so they cannot be scoped by name.
        Sid    = "ReadTheBackups"
        Effect = "Allow"
        Action = [
          "backup:Describe*",
          "backup:Get*",
        ]
        Resource = [
          "arn:aws:backup:${local.region}:${local.account_id}:backup-vault:${local.prefix}-snapshots",
          "arn:aws:backup:${local.region}:${local.account_id}:backup-plan:*",
        ]
      },
      {
        # Gap: backup list actions (ListTags among them) are not all
        # resource-scoped. They disclose metadata only.
        Sid      = "ListBackups"
        Effect   = "Allow"
        Action   = "backup:List*"
        Resource = "*"
      },
      {
        Sid    = "ReadTheAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListTagsForResource",
        ]
        Resource = "arn:aws:cloudwatch:${local.region}:${local.account_id}:alarm:${local.prefix}-*"
      },
      {
        # The watchdog topic and its subscription (whose ARN starts with the
        # topic's).
        Sid    = "ReadTheTopic"
        Effect = "Allow"
        Action = [
          "sns:GetTopicAttributes",
          "sns:GetSubscriptionAttributes",
          "sns:ListTagsForResource",
        ]
        Resource = "arn:aws:sns:${local.region}:${local.account_id}:${local.prefix}-*"
      },
      {
        # The off-hours page: its certificate, distribution and function, for
        # refresh and while the apply waits, as in static-site/read: only what
        # is tagged Project = <project>.
        Sid    = "ReadTheOffHoursPage"
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:ListTagsForCertificate",
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:DescribeFunction",
          "cloudfront:GetFunction",
          "cloudfront:ListTagsForResource",
        ]
        Resource = [
          "arn:aws:acm:us-east-1:${local.account_id}:certificate/*",
          "arn:aws:cloudfront::${local.account_id}:distribution/*",
          "arn:aws:cloudfront::${local.account_id}:function/${local.prefix}-off-hours-page",
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/Project" = var.project
          }
        }
      },
    ], local.zone_statements)
  }
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = "CI policy monitoring/read: read the monitoring stack's node, data volume, security group, roles, functions, schedules, log groups, parameters, config bucket, snapshots, alarms, topic and record"
  policy      = jsonencode(local.policy)

  tags = {
    Component = "ci"
  }
}
