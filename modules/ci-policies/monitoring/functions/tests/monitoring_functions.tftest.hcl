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
  name      = "jaws-monitoring-ci-apply-monitoring-functions"
  name_root = "jaws"
  project   = "monitoring"
}

run "monitoring_functions_grants_exactly_these_statements" {
  command = plan

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheFunctions"])) == jsonencode({
      Sid    = "ManageTheFunctions"
      Effect = "Allow"
      Action = [
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:TagResource",
        "lambda:UntagResource",
        "lambda:AddPermission",
        "lambda:RemovePermission",
      ]
      Resource = "arn:aws:lambda:us-east-1:123456789012:function:jaws-monitoring-*"
    })
    error_message = "the normalizer and the watchdog: lifecycle, code, configuration, tags and the SNS permission"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "UseThePandasLayer"])) == jsonencode({
      Sid      = "UseThePandasLayer"
      Effect   = "Allow"
      Action   = "lambda:GetLayerVersion"
      Resource = "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python313-Arm64:*"
    })
    error_message = "a function is created with a layer only by a caller that may get that layer: the normalizer's default AWS SDK for pandas layer"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheLogGroups"])) == jsonencode({
      Sid    = "ManageTheLogGroups"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "logs:DeleteRetentionPolicy",
        "logs:TagResource",
        "logs:UntagResource",
      ]
      Resource = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/jaws-monitoring-*"
    })
    error_message = "the functions' log groups only"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheTopic"])) == jsonencode({
      Sid    = "ManageTheTopic"
      Effect = "Allow"
      Action = [
        "sns:CreateTopic",
        "sns:DeleteTopic",
        "sns:SetTopicAttributes",
        "sns:TagResource",
        "sns:UntagResource",
        "sns:Subscribe",
        "sns:Unsubscribe",
      ]
      Resource = "arn:aws:sns:us-east-1:123456789012:jaws-monitoring-*"
    })
    error_message = "the watchdog topic and its Lambda subscription"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheAlarms"])) == jsonencode({
      Sid    = "ManageTheAlarms"
      Effect = "Allow"
      Action = [
        "cloudwatch:PutMetricAlarm",
        "cloudwatch:DeleteAlarms",
        "cloudwatch:TagResource",
        "cloudwatch:UntagResource",
      ]
      Resource = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:jaws-monitoring-*"
    })
    error_message = "the two status-check alarms"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheSchedules"])) == jsonencode({
      Sid    = "ManageTheSchedules"
      Effect = "Allow"
      Action = [
        "scheduler:CreateSchedule",
        "scheduler:UpdateSchedule",
        "scheduler:DeleteSchedule",
      ]
      Resource = "arn:aws:scheduler:us-east-1:123456789012:schedule/default/jaws-monitoring-*"
    })
    error_message = "the start, stop, watchdog and normalizer schedules, in the default group"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "PassTheFunctionAndScheduleRoles"])) == jsonencode({
      Sid       = "PassTheFunctionAndScheduleRoles"
      Effect    = "Allow"
      Action    = "iam:PassRole"
      Resource  = "arn:aws:iam::123456789012:role/jaws-monitoring-*"
      Condition = { StringEquals = { "iam:PassedToService" = ["lambda.amazonaws.com", "scheduler.amazonaws.com"] } }
    })
    error_message = "the stack's <prefix>-* roles, only to Lambda and EventBridge Scheduler"
  }
}

run "monitoring_functions_grants_nothing_else" {
  command = plan

  assert {
    condition = jsonencode(sort([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid])) == jsonencode(sort([
      "ManageTheFunctions",
      "UseThePandasLayer",
      "ManageTheLogGroups",
      "ManageTheTopic",
      "ManageTheAlarms",
      "ManageTheSchedules",
      "PassTheFunctionAndScheduleRoles",
    ]))
    error_message = "monitoring/functions is exactly these statements"
  }

  assert {
    condition     = !anytrue([for s in jsondecode(aws_iam_policy.this.policy).Statement : contains(tolist(flatten([s.Resource])), "*")])
    error_message = "no statement is unscoped"
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.this.policy).Statement :
      try(s.Condition.StringEquals["iam:PassedToService"], null) != null if contains(tolist(flatten([s.Action])), "iam:PassRole")
    ])
    error_message = "every iam:PassRole names the services it passes to"
  }

  assert {
    condition     = !anytrue([for s in jsondecode(aws_iam_policy.this.policy).Statement : contains(tolist(flatten([s.Action])), "iam:CreateServiceLinkedRole")])
    error_message = "service-linked roles belong to the account's foundation stack, never a project's"
  }

  # The pandas layer is AWS's own; the only read this write policy holds.
  assert {
    condition = jsonencode([
      for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) :
      a if can(regex("^[a-z0-9]+:(Describe|Get|List)", a))
    ]) == jsonencode(["lambda:GetLayerVersion"])
    error_message = "a write policy grants no reads but the layer lookup CreateFunction needs; monitoring/read has the rest"
  }
}

# `description` forces replacement of the policy, which would detach it from
# every role mid-apply. It is frozen; change the README instead.
run "description_is_frozen" {
  command = plan

  assert {
    condition     = aws_iam_policy.this.description == "CI policy monitoring/functions: manage the monitoring stack's functions, log groups, schedules, alarms and topic, and pass their roles to Lambda and EventBridge Scheduler"
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
