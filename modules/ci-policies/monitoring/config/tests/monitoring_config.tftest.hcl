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
  name      = "jaws-monitoring-ci-apply-monitoring-config"
  name_root = "jaws"
  project   = "monitoring"
  zone_id   = "Z0123456789ABCDEFGHIJ"
  domain    = "grafana.example.com"
}

run "monitoring_config_grants_exactly_these_statements" {
  command = plan

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheConfigBucket"])) == jsonencode({
      Sid    = "ManageTheConfigBucket"
      Effect = "Allow"
      Action = [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:PutBucketTagging",
        "s3:PutBucketOwnershipControls",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
      ]
      Resource = "arn:aws:s3:::jaws-monitoring-config-123456789012"
    })
    error_message = "the config bucket and each configuration resource the node module gives it"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "WriteTheConfigObjects"])) == jsonencode({
      Sid    = "WriteTheConfigObjects"
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
      ]
      Resource = "arn:aws:s3:::jaws-monitoring-config-123456789012/*"
    })
    error_message = "the bundles, tagged, and every version of a replaced bundle"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheParameters"])) == jsonencode({
      Sid    = "ManageTheParameters"
      Effect = "Allow"
      Action = [
        "ssm:PutParameter",
        "ssm:DeleteParameter",
        "ssm:AddTagsToResource",
        "ssm:RemoveTagsFromResource",
      ]
      Resource = "arn:aws:ssm:us-east-1:123456789012:parameter/jaws-monitoring/*"
    })
    error_message = "parameters under /<prefix>/ only"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ChangeTheNodeRecord"])) == jsonencode({
      Sid      = "ChangeTheNodeRecord"
      Effect   = "Allow"
      Action   = "route53:ChangeResourceRecordSets"
      Resource = "arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"
      Condition = {
        "ForAllValues:StringEquals" = {
          "route53:ChangeResourceRecordSetsNormalizedRecordNames" = ["grafana.example.com"]
        }
      }
    })
    error_message = "the one record, by its normalized name, in the one zone"
  }
}

run "monitoring_config_grants_nothing_else" {
  command = plan

  assert {
    condition = jsonencode(sort([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid])) == jsonencode(sort([
      "ManageTheConfigBucket",
      "WriteTheConfigObjects",
      "ManageTheParameters",
      "ChangeTheNodeRecord",
    ]))
    error_message = "monitoring/config is exactly these statements"
  }

  assert {
    condition     = !anytrue([for s in jsondecode(aws_iam_policy.this.policy).Statement : contains(tolist(flatten([s.Resource])), "*")])
    error_message = "no statement is unscoped"
  }

  assert {
    condition = alltrue([
      for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) :
      !can(regex("^[a-z0-9]+:(Describe|Get|List)", a))
    ])
    error_message = "a write policy grants no reads; monitoring/read has them"
  }
}

run "monitoring_config_without_a_domain_changes_no_records" {
  command = plan

  variables {
    zone_id = null
    domain  = null
  }

  assert {
    condition     = !anytrue([for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) : startswith(a, "route53:")])
    error_message = "without a zone and domain the policy changes nothing in Route 53"
  }

  assert {
    condition     = jsonencode(sort([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid])) == jsonencode(["ManageTheConfigBucket", "ManageTheParameters", "WriteTheConfigObjects"])
    error_message = "without a zone and domain the policy is the bucket, object and parameter statements"
  }
}

run "monitoring_config_normalizes_the_record_name" {
  command = plan

  variables {
    domain = "grafana.example.com."
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Condition["ForAllValues:StringEquals"]["route53:ChangeResourceRecordSetsNormalizedRecordNames"] if s.Sid == "ChangeTheNodeRecord"]) == ["grafana.example.com"]
    error_message = "Route 53 normalizes names without the trailing dot"
  }
}

run "rejects_a_zone_without_a_domain" {
  command = plan

  variables {
    domain = null
  }

  expect_failures = [var.domain]
}

run "rejects_a_domain_without_a_zone" {
  command = plan

  variables {
    zone_id = null
  }

  expect_failures = [var.domain]
}

run "rejects_a_malformed_zone_id" {
  command = plan

  variables {
    zone_id = "hostedzone/Z0123456789ABCDEFGHIJ"
  }

  expect_failures = [var.zone_id]
}

run "rejects_a_wildcard_domain" {
  command = plan

  variables {
    domain = "*.grafana.example.com"
  }

  expect_failures = [var.domain]
}

# `description` forces replacement of the policy, which would detach it from
# every role mid-apply. It is frozen; change the README instead.
run "description_is_frozen" {
  command = plan

  assert {
    condition     = aws_iam_policy.this.description == "CI policy monitoring/config: manage the monitoring node's config bucket and bundles, its parameters and its DNS record"
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
