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
  name      = "jaws-monitoring-ci-plan-monitoring-read"
  name_root = "jaws"
  project   = "monitoring"
  zone_id   = "Z0123456789ABCDEFGHIJ"
}

run "monitoring_read_grants_exactly_these_statements" {
  command = plan

  # Every refresh describe: the instance (attributes, credit specification),
  # its volumes, the security group and its rules, the subnet and the AMI.
  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "DescribeEc2"])) == jsonencode({
      Sid      = "DescribeEc2"
      Effect   = "Allow"
      Action   = "ec2:Describe*"
      Resource = "*"
    })
    error_message = "DescribeEc2 is ec2:Describe* on *, a documented gap"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheRoles"])) == jsonencode({
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
        "arn:aws:iam::123456789012:role/jaws-monitoring",
        "arn:aws:iam::123456789012:role/jaws-monitoring-*",
        "arn:aws:iam::123456789012:instance-profile/jaws-monitoring",
      ]
    })
    error_message = "ReadTheRoles reads the node's role and profile by their exact name and the stack's other roles by prefix"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheFunctions"])) == jsonencode({
      Sid    = "ReadTheFunctions"
      Effect = "Allow"
      Action = [
        "lambda:GetFunction*",
        "lambda:GetPolicy",
        "lambda:ListVersionsByFunction",
        "lambda:ListTags",
      ]
      Resource = "arn:aws:lambda:us-east-1:123456789012:function:jaws-monitoring-*"
    })
    error_message = "ReadTheFunctions reads the normalizer and the watchdog, their code signing, versions, permissions and tags"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheSchedules"])) == jsonencode({
      Sid      = "ReadTheSchedules"
      Effect   = "Allow"
      Action   = "scheduler:GetSchedule"
      Resource = "arn:aws:scheduler:us-east-1:123456789012:schedule/default/jaws-monitoring-*"
    })
    error_message = "ReadTheSchedules reads the start, stop, watchdog and normalizer schedules"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "DescribeLogGroups"])) == jsonencode({
      Sid      = "DescribeLogGroups"
      Effect   = "Allow"
      Action   = "logs:DescribeLogGroups"
      Resource = "*"
    })
    error_message = "DescribeLogGroups is on *, a documented gap"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheLogGroups"])) == jsonencode({
      Sid      = "ReadTheLogGroups"
      Effect   = "Allow"
      Action   = "logs:ListTagsForResource"
      Resource = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/jaws-monitoring-*"
    })
    error_message = "ReadTheLogGroups reads the tags of the functions' log groups"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "DescribeParameters"])) == jsonencode({
      Sid      = "DescribeParameters"
      Effect   = "Allow"
      Action   = "ssm:DescribeParameters"
      Resource = "*"
    })
    error_message = "DescribeParameters is on *, a documented gap"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheParameters"])) == jsonencode({
      Sid    = "ReadTheParameters"
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:ListTagsForResource",
      ]
      Resource = "arn:aws:ssm:us-east-1:123456789012:parameter/jaws-monitoring/*"
    })
    error_message = "ReadTheParameters reads /<prefix>/*"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheConfigBucket"])) == jsonencode({
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
      Resource = "arn:aws:s3:::jaws-monitoring-config-123456789012"
    })
    error_message = "ReadTheConfigBucket reads everything aws_s3_bucket refreshes, and lists object versions for the bundle's delete"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheConfigObjects"])) == jsonencode({
      Sid    = "ReadTheConfigObjects"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:GetObjectTagging",
      ]
      Resource = "arn:aws:s3:::jaws-monitoring-config-123456789012/*"
    })
    error_message = "ReadTheConfigObjects reads the bundles and their tags, in the config bucket only"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheBackups"])) == jsonencode({
      Sid    = "ReadTheBackups"
      Effect = "Allow"
      Action = [
        "backup:Describe*",
        "backup:Get*",
      ]
      Resource = [
        "arn:aws:backup:us-east-1:123456789012:backup-vault:jaws-monitoring-snapshots",
        "arn:aws:backup:us-east-1:123456789012:backup-plan:*",
      ]
    })
    error_message = "ReadTheBackups reads the vault by name and backup plans, which are named by a random ID"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ListBackups"])) == jsonencode({
      Sid      = "ListBackups"
      Effect   = "Allow"
      Action   = "backup:List*"
      Resource = "*"
    })
    error_message = "ListBackups is on *, a documented gap"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheOffHoursPage"])) == jsonencode({
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
        "arn:aws:acm:us-east-1:123456789012:certificate/*",
        "arn:aws:cloudfront::123456789012:distribution/*",
        "arn:aws:cloudfront::123456789012:function/jaws-monitoring-off-hours-page",
      ]
    })
    error_message = "ReadTheOffHoursPage reads the off-hours page's certificate, distribution and function"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheAlarms"])) == jsonencode({
      Sid    = "ReadTheAlarms"
      Effect = "Allow"
      Action = [
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListTagsForResource",
      ]
      Resource = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:jaws-monitoring-*"
    })
    error_message = "ReadTheAlarms reads the two status-check alarms"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheTopic"])) == jsonencode({
      Sid    = "ReadTheTopic"
      Effect = "Allow"
      Action = [
        "sns:GetTopicAttributes",
        "sns:GetSubscriptionAttributes",
        "sns:ListTagsForResource",
      ]
      Resource = "arn:aws:sns:us-east-1:123456789012:jaws-monitoring-*"
    })
    error_message = "ReadTheTopic reads the watchdog topic and its subscription"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadTheZone"])) == jsonencode({
      Sid    = "ReadTheZone"
      Effect = "Allow"
      Action = [
        "route53:GetHostedZone",
        "route53:ListResourceRecordSets",
      ]
      Resource = "arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"
    })
    error_message = "ReadTheZone reads the one hosted zone the node's record is in"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ReadRoute53Changes"])) == jsonencode({
      Sid      = "ReadRoute53Changes"
      Effect   = "Allow"
      Action   = "route53:GetChange"
      Resource = "arn:aws:route53:::change/*"
    })
    error_message = "ReadRoute53Changes polls the record's change"
  }
}

run "monitoring_read_grants_nothing_else" {
  command = plan

  assert {
    condition = jsonencode(sort([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid])) == jsonencode(sort([
      "DescribeEc2",
      "ReadTheRoles",
      "ReadTheFunctions",
      "ReadTheSchedules",
      "DescribeLogGroups",
      "ReadTheLogGroups",
      "DescribeParameters",
      "ReadTheParameters",
      "ReadTheConfigBucket",
      "ReadTheConfigObjects",
      "ReadTheBackups",
      "ListBackups",
      "ReadTheAlarms",
      "ReadTheTopic",
      "ReadTheOffHoursPage",
      "ReadTheZone",
      "ReadRoute53Changes",
    ]))
    error_message = "monitoring/read is exactly these statements"
  }

  assert {
    condition     = jsonencode(sort([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid if s.Resource == "*"])) == jsonencode(["DescribeEc2", "DescribeLogGroups", "DescribeParameters", "ListBackups"])
    error_message = "only the documented gaps may use Resource = *"
  }

  assert {
    condition     = alltrue([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Effect == "Allow" && try(s.Condition, null) == null])
    error_message = "every statement is an unconditioned Allow"
  }

  assert {
    condition = alltrue([
      for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) :
      can(regex("^[a-z0-9]+:(Describe|Get|List)", a))
    ])
    error_message = "monitoring/read grants only Describe, Get and List actions"
  }
}

run "monitoring_read_without_a_zone_reads_no_records" {
  command = plan

  variables {
    zone_id = null
  }

  assert {
    condition     = !anytrue([for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) : startswith(a, "route53:")])
    error_message = "without a zone the policy reads nothing in Route 53"
  }

  assert {
    condition     = length(jsondecode(aws_iam_policy.this.policy).Statement) == 15
    error_message = "without a zone the policy is the other 15 statements"
  }
}

run "rejects_a_malformed_zone_id" {
  command = plan

  variables {
    zone_id = "hostedzone/Z0123456789ABCDEFGHIJ"
  }

  expect_failures = [var.zone_id]
}

# `description` forces replacement of the policy, which would detach it from
# every role mid-apply. It is frozen; change the README instead.
run "description_is_frozen" {
  command = plan

  assert {
    condition     = aws_iam_policy.this.description == "CI policy monitoring/read: read the monitoring stack's node, data volume, security group, roles, functions, schedules, log groups, parameters, config bucket, snapshots, alarms, topic and record"
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
