data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  prefix     = "${var.name_root}-${var.project}"

  # Write-only: pair it with monitoring/read, which the apply role also needs
  # for refresh.
  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        # The normalizer (<prefix>-normalizer) and the watchdog
        # (<prefix>-watchdog), and the watchdog's permission for SNS.
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
        Resource = "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.prefix}-*"
      },
      {
        # Creating or configuring a function with a layer needs GetLayerVersion
        # on it. The normalizer's default: the AWS SDK for pandas layer, which
        # AWS publishes from its own account.
        Sid      = "UseThePandasLayer"
        Effect   = "Allow"
        Action   = "lambda:GetLayerVersion"
        Resource = "arn:aws:lambda:${local.region}:336392948345:layer:AWSSDKPandas-Python313-Arm64:*"
      },
      {
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
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.prefix}-*"
      },
      {
        # The watchdog topic and its Lambda subscription, whose ARN starts
        # with the topic's.
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
        Resource = "arn:aws:sns:${local.region}:${local.account_id}:${local.prefix}-*"
      },
      {
        # The two status-check alarms (their EC2 recover and reboot actions
        # run as CloudWatch's service-linked role, below).
        Sid    = "ManageTheAlarms"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
        ]
        Resource = "arn:aws:cloudwatch:${local.region}:${local.account_id}:alarm:${local.prefix}-*"
      },
      {
        # PutMetricAlarm with an EC2 action needs iam:CreateServiceLinkedRole
        # for every such alarm (the API reference), not only when the role is
        # missing. It can create only CloudWatch's own AWS-defined role.
        Sid       = "CreateTheAlarmActionsRole"
        Effect    = "Allow"
        Action    = "iam:CreateServiceLinkedRole"
        Resource  = "arn:aws:iam::${local.account_id}:role/aws-service-role/events.amazonaws.com/AWSServiceRoleForCloudWatchEvents"
        Condition = { StringEquals = { "iam:AWSServiceName" = "events.amazonaws.com" } }
      },
      {
        # The node's start and stop, the watchdog's and the normalizer's
        # schedules; schedules carry no tags.
        Sid    = "ManageTheSchedules"
        Effect = "Allow"
        Action = [
          "scheduler:CreateSchedule",
          "scheduler:UpdateSchedule",
          "scheduler:DeleteSchedule",
        ]
        Resource = "arn:aws:scheduler:${local.region}:${local.account_id}:schedule/default/${local.prefix}-*"
      },
      {
        # The functions' roles to Lambda, the schedules' roles to EventBridge
        # Scheduler. The node's own role (<prefix>) is not matched.
        Sid       = "PassTheFunctionAndScheduleRoles"
        Effect    = "Allow"
        Action    = "iam:PassRole"
        Resource  = "arn:aws:iam::${local.account_id}:role/${local.prefix}-*"
        Condition = { StringEquals = { "iam:PassedToService" = ["lambda.amazonaws.com", "scheduler.amazonaws.com"] } }
      },
    ]
  }
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = "CI policy monitoring/functions: manage the monitoring stack's functions, log groups, schedules, alarms and topic, and pass their roles to Lambda and EventBridge Scheduler"
  policy      = jsonencode(local.policy)

  tags = {
    Component = "ci"
  }
}
