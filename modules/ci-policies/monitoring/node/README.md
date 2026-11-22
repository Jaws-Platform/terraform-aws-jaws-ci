# monitoring/node

Create and manage the monitoring node of
[`jaws-monitoring`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest)
([`monitoring-node`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest/submodules/monitoring-node)):
its EC2 instance and root volume, its data volume and the attachment, its
security group and rules, and every IAM role of the stack (the node's, the
off-hours schedule's, the snapshots', the watchdog's and its schedule's, the
normalizer's and its scheduler's) with their inline policies, plus the node's
instance profile. Class: **write**.

Write policies grant no reads; pair it with
[`monitoring/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/read)
on the apply role.

Part of the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["monitoring/node"]`; it is not meant to be called directly.

## How it is scoped

- **EC2 by tag.** Create calls (`RunInstances`, `CreateVolume`,
  `CreateSecurityGroup`, tagged rules) require
  `aws:RequestTag/Project = <project>`, and every later change, delete or tag
  change requires `aws:ResourceTag/Project = <project>`. This only works
  because the stack's provider `default_tags` carry `Project`, for example
  from the
  [`context`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/context)
  module.
- **IAM by name.** Roles are `<name_root>-<project>` (the node's) and
  `<name_root>-<project>-*` (all the others); the instance profile is exactly
  `<name_root>-<project>`. `iam:AttachRolePolicy` attaches only
  `AWSBackupServiceRolePolicyForBackup`, and only to
  `<name_root>-<project>-snapshots`. `iam:PassRole` passes only the node's role,
  and only to `ec2.amazonaws.com`.

`RunInstancesDependencies` names the image, network interface, subnet and
security group resource types without a tag condition, because
`RunInstances` authorizes against them, a public AMI cannot carry the
project's tag and the subnet belongs to the network stack.
`CreateTheSecurityGroupInItsVpc` names `vpc/*` for the same reason: the VPC is
the network stack's. Neither lets the role change those resources.

## Known limitation

Like [`container/manage`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/container/manage), this policy can edit
the inline policies of `<name_root>-<project>` and `<name_root>-<project>-*`
roles. A role holding it can therefore grant the stack's roles more access.
Protect the environment the apply role trusts.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11 |
| aws | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name of the managed policy, for example `acme-monitoring-ci-apply-monitoring-node`. | `string` | n/a | yes |
| name\_root | Prefix of resource names, in kebab-case. The monitoring stack names everything from `<name_root>-<project>`: roles, functions, schedules, alarms, the topic and the vault are `<name_root>-<project>` or `<name_root>-<project>-*`, parameters `/<name_root>-<project>/*`. | `string` | n/a | yes |
| project | Project name in kebab-case. Role and instance profile ARNs are built from `<name_root>-<project>`; EC2 is scoped by the `Project = <project>` tag the provider's `default_tags` put on every resource. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
