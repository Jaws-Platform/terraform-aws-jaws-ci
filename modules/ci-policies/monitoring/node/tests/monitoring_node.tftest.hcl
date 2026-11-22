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
  name      = "jaws-monitoring-ci-apply-monitoring-node"
  name_root = "jaws"
  project   = "monitoring"
}

run "monitoring_node_grants_exactly_these_statements" {
  command = plan

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "RunTheNode"])) == jsonencode({
      Sid    = "RunTheNode"
      Effect = "Allow"
      Action = "ec2:RunInstances"
      Resource = [
        "arn:aws:ec2:us-east-1:123456789012:instance/*",
        "arn:aws:ec2:us-east-1:123456789012:volume/*",
      ]
      Condition = { StringEquals = { "aws:RequestTag/Project" = "monitoring" } }
    })
    error_message = "the instance and its root volume are launched only with Project = <project>"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "RunInstancesDependencies"])) == jsonencode({
      Sid    = "RunInstancesDependencies"
      Effect = "Allow"
      Action = "ec2:RunInstances"
      Resource = [
        "arn:aws:ec2:us-east-1::image/*",
        "arn:aws:ec2:us-east-1:123456789012:network-interface/*",
        "arn:aws:ec2:us-east-1:123456789012:subnet/*",
        "arn:aws:ec2:us-east-1:123456789012:security-group/*",
      ]
    })
    error_message = "RunInstances also authorizes against the Amazon image, the interface, the network stack's subnet and the group"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "CreateTheDataVolume"])) == jsonencode({
      Sid       = "CreateTheDataVolume"
      Effect    = "Allow"
      Action    = "ec2:CreateVolume"
      Resource  = "arn:aws:ec2:us-east-1:123456789012:volume/*"
      Condition = { StringEquals = { "aws:RequestTag/Project" = "monitoring" } }
    })
    error_message = "the data volume is created only with Project = <project>"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "CreateTheSecurityGroup"])) == jsonencode({
      Sid       = "CreateTheSecurityGroup"
      Effect    = "Allow"
      Action    = "ec2:CreateSecurityGroup"
      Resource  = "arn:aws:ec2:us-east-1:123456789012:security-group/*"
      Condition = { StringEquals = { "aws:RequestTag/Project" = "monitoring" } }
    })
    error_message = "the security group is created only with Project = <project>"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "CreateTheSecurityGroupInItsVpc"])) == jsonencode({
      Sid      = "CreateTheSecurityGroupInItsVpc"
      Effect   = "Allow"
      Action   = "ec2:CreateSecurityGroup"
      Resource = "arn:aws:ec2:us-east-1:123456789012:vpc/*"
    })
    error_message = "the group is created in a VPC the network stack owns, so the VPC carries no condition"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "CreateTheSecurityGroupRules"])) == jsonencode({
      Sid    = "CreateTheSecurityGroupRules"
      Effect = "Allow"
      Action = [
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
      ]
      Resource  = "arn:aws:ec2:us-east-1:123456789012:security-group-rule/*"
      Condition = { StringEquals = { "aws:RequestTag/Project" = "monitoring" } }
    })
    error_message = "tagged rules are new security-group-rule resources, created only with Project = <project>"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "TagOnCreate"])) == jsonencode({
      Sid    = "TagOnCreate"
      Effect = "Allow"
      Action = "ec2:CreateTags"
      Resource = [
        "arn:aws:ec2:us-east-1:123456789012:instance/*",
        "arn:aws:ec2:us-east-1:123456789012:volume/*",
        "arn:aws:ec2:us-east-1:123456789012:security-group/*",
        "arn:aws:ec2:us-east-1:123456789012:security-group-rule/*",
      ]
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
    })
    error_message = "tags on create only through the create calls this policy allows"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheTaggedEc2"])) == jsonencode({
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
      Resource = [
        "arn:aws:ec2:us-east-1:123456789012:instance/*",
        "arn:aws:ec2:us-east-1:123456789012:volume/*",
        "arn:aws:ec2:us-east-1:123456789012:security-group/*",
        "arn:aws:ec2:us-east-1:123456789012:security-group-rule/*",
      ]
      Condition = { StringEquals = { "aws:ResourceTag/Project" = "monitoring" } }
    })
    error_message = "every change, delete and tag change needs Project = <project> on the resource"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "ManageTheRoles"])) == jsonencode({
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
        "arn:aws:iam::123456789012:role/jaws-monitoring",
        "arn:aws:iam::123456789012:role/jaws-monitoring-*",
        "arn:aws:iam::123456789012:instance-profile/jaws-monitoring",
      ]
    })
    error_message = "the stack's roles, their inline policies, and the node's instance profile"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "AttachTheBackupServicePolicy"])) == jsonencode({
      Sid       = "AttachTheBackupServicePolicy"
      Effect    = "Allow"
      Action    = "iam:AttachRolePolicy"
      Resource  = "arn:aws:iam::123456789012:role/jaws-monitoring-snapshots"
      Condition = { ArnEquals = { "iam:PolicyARN" = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup" } }
    })
    error_message = "the one managed policy, on the snapshots role only"
  }

  assert {
    condition = jsonencode(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s if s.Sid == "PassTheNodeRole"])) == jsonencode({
      Sid       = "PassTheNodeRole"
      Effect    = "Allow"
      Action    = "iam:PassRole"
      Resource  = "arn:aws:iam::123456789012:role/jaws-monitoring"
      Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } }
    })
    error_message = "only the node's role, and only to EC2"
  }
}

run "monitoring_node_grants_nothing_else" {
  command = plan

  assert {
    condition = jsonencode(sort([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Sid])) == jsonencode(sort([
      "RunTheNode",
      "RunInstancesDependencies",
      "CreateTheDataVolume",
      "CreateTheSecurityGroup",
      "CreateTheSecurityGroupInItsVpc",
      "CreateTheSecurityGroupRules",
      "TagOnCreate",
      "ManageTheTaggedEc2",
      "ManageTheRoles",
      "AttachTheBackupServicePolicy",
      "PassTheNodeRole",
    ]))
    error_message = "monitoring/node is exactly these statements"
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
    error_message = "every iam:PassRole names the service it passes to"
  }

  assert {
    condition = alltrue([
      for a in flatten([for s in jsondecode(aws_iam_policy.this.policy).Statement : tolist(flatten([s.Action]))]) :
      !can(regex("^[a-z0-9]+:(Describe|Get|List)", a))
    ])
    error_message = "a write policy grants no reads; monitoring/read has them"
  }
}

# The node's role and instance profile are named exactly <prefix>, which
# <prefix>-* does not match.
run "monitoring_node_manages_the_node_role_by_its_exact_name" {
  command = plan

  assert {
    condition = alltrue([
      for r in [
        "arn:aws:iam::123456789012:role/jaws-monitoring",
        "arn:aws:iam::123456789012:role/jaws-monitoring-*",
        "arn:aws:iam::123456789012:instance-profile/jaws-monitoring",
      ] : contains(one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Resource if s.Sid == "ManageTheRoles"]), r)
    ])
    error_message = "ManageTheRoles must list role/<prefix>, role/<prefix>-* and instance-profile/<prefix>"
  }

  assert {
    condition     = one([for s in jsondecode(aws_iam_policy.this.policy).Statement : s.Resource if s.Sid == "PassTheNodeRole"]) == "arn:aws:iam::123456789012:role/jaws-monitoring"
    error_message = "the node's role is passed by its exact name"
  }
}

# `description` forces replacement of the policy, which would detach it from
# every role mid-apply. It is frozen; change the README instead.
run "description_is_frozen" {
  command = plan

  assert {
    condition     = aws_iam_policy.this.description == "CI policy monitoring/node: create and manage the monitoring node's instance, data volume, security group, roles and instance profile"
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
