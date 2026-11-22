data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
  prefix     = "${var.name_root}-${var.project}"
  ec2        = "arn:aws:ec2:${local.region}:${local.account_id}"
  iam        = "arn:aws:iam::${local.account_id}"

  # The provider's default_tags put Project on every EC2 resource the stack
  # creates; the monitoring module adds Component = monitoring.
  request_tag  = { StringEquals = { "aws:RequestTag/Project" = var.project } }
  resource_tag = { StringEquals = { "aws:ResourceTag/Project" = var.project } }

  # The node's EC2 resources: its instance, root and data volumes, security
  # group and the group's rules.
  node_resources = [
    "${local.ec2}:instance/*",
    "${local.ec2}:volume/*",
    "${local.ec2}:security-group/*",
    "${local.ec2}:security-group-rule/*",
  ]

  # Write-only: pair it with monitoring/read, which the apply role also needs
  # for refresh.
  policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "RunTheNode"
        Effect    = "Allow"
        Action    = "ec2:RunInstances"
        Resource  = ["${local.ec2}:instance/*", "${local.ec2}:volume/*"]
        Condition = local.request_tag
      },
      {
        # The other resources RunInstances authorizes against. The image is a
        # public Amazon image, in no account; the subnet is the network
        # stack's, so it does not carry this project's tag.
        Sid    = "RunInstancesDependencies"
        Effect = "Allow"
        Action = "ec2:RunInstances"
        Resource = [
          "arn:aws:ec2:${local.region}::image/*",
          "${local.ec2}:network-interface/*",
          "${local.ec2}:subnet/*",
          "${local.ec2}:security-group/*",
        ]
      },
      {
        Sid       = "CreateTheDataVolume"
        Effect    = "Allow"
        Action    = "ec2:CreateVolume"
        Resource  = "${local.ec2}:volume/*"
        Condition = local.request_tag
      },
      {
        Sid       = "CreateTheSecurityGroup"
        Effect    = "Allow"
        Action    = "ec2:CreateSecurityGroup"
        Resource  = "${local.ec2}:security-group/*"
        Condition = local.request_tag
      },
      {
        # CreateSecurityGroup also authorizes against the VPC, which the
        # network stack owns and tags with its own project.
        Sid      = "CreateTheSecurityGroupInItsVpc"
        Effect   = "Allow"
        Action   = "ec2:CreateSecurityGroup"
        Resource = "${local.ec2}:vpc/*"
      },
      {
        # A rule created with tags (aws_vpc_security_group_*_rule) is a new
        # security-group-rule resource, authorized by its request tags; the
        # group itself is covered by ManageTheTaggedEc2.
        Sid    = "CreateTheSecurityGroupRules"
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
        ]
        Resource  = "${local.ec2}:security-group-rule/*"
        Condition = local.request_tag
      },
      {
        # Tags applied by a create call, bounded to the create calls above,
        # each of which already requires the Project tag.
        Sid      = "TagOnCreate"
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = local.node_resources
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "RunInstances",
              "CreateVolume",
              "CreateSecurityGroup",
              "AuthorizeSecurityGroupIngress",
              "AuthorizeSecurityGroupEgress",
            ]
          }
        }
      },
      {
        # Everything after create, bounded by the Project tag. Stop: the data
        # volume is detached with stop_instance_before_detaching, and a type
        # change stops the instance. CreateTags: the provider tags the root
        # volume again after launch (no ec2:CreateAction), when it already
        # carries Project. Revoke: the provider removes a new group's default
        # egress rule.
        Sid    = "ManageTheTaggedEc2"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyInstanceMetadataOptions",
          "ec2:ModifyInstanceCreditSpecification",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:DeleteVolume",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifySecurityGroupRules",
          "ec2:DeleteSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
        ]
        Resource  = local.node_resources
        Condition = local.resource_tag
      },
      {
        # The node's role and instance profile are named exactly <prefix>;
        # the schedule, snapshots, watchdog and normalizer roles <prefix>-*.
        Sid    = "ManageTheRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:UpdateRoleDescription",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile",
        ]
        Resource = [
          "${local.iam}:role/${local.prefix}",
          "${local.iam}:role/${local.prefix}-*",
          "${local.iam}:instance-profile/${local.prefix}",
        ]
      },
      {
        # Every other role policy is inline. AWS Backup's role takes AWS's own.
        Sid       = "AttachTheBackupServicePolicy"
        Effect    = "Allow"
        Action    = "iam:AttachRolePolicy"
        Resource  = "${local.iam}:role/${local.prefix}-snapshots"
        Condition = { ArnEquals = { "iam:PolicyARN" = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup" } }
      },
      {
        Sid       = "PassTheNodeRole"
        Effect    = "Allow"
        Action    = "iam:PassRole"
        Resource  = "${local.iam}:role/${local.prefix}"
        Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } }
      },
    ]
  }
}

resource "aws_iam_policy" "this" {
  name        = var.name
  description = "CI policy monitoring/node: create and manage the monitoring node's instance, data volume, security group, roles and instance profile"
  policy      = jsonencode(local.policy)

  tags = {
    Component = "ci"
  }
}
