# monitoring/read

Read everything `terraform plan` refreshes in the monitoring stack, the root
module of
[`jaws-monitoring`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest)
(the billing normalizer and the monitoring node): describe EC2 (the instance,
its data volume, its security group and rules, the subnet and the AMI), read
the stack's roles and the node's instance profile, its two functions with
their permissions, its schedules, the tags of its log groups, its parameters,
the config bucket's configuration and bundles, the snapshot vault and plan, the
status-check alarms, the watchdog topic and, with a `zone_id`, the node's
hosted zone. Class: **read**.

Every name is `<name_root>-<project>`, the monitoring module's `name`: the
node's role and instance profile are exactly that name, everything else starts
with `<name_root>-<project>-`. Parameters are read under
`/<name_root>-<project>/`; the owner's secrets (the Grafana credentials and
Slack webhooks) are never read by Terraform, so keep them elsewhere, for
example under `/<name_root>/<project>/`.

It changes nothing; pair it with
[`monitoring/node`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/node),
[`monitoring/config`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/config),
[`monitoring/functions`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/functions)
and [`monitoring/backup`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/backup)
on the apply role.

Part of the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["monitoring/read"]` and, when the node has a record,
`policy_inputs = { monitoring = { zone_id, domain } }`; it is not meant to be
called directly.

## Known gaps

| Statement | Why it is `*` |
|---|---|
| `DescribeEc2` (`ec2:Describe*`) | EC2 describe actions have no resource-level support. They disclose metadata about every instance, volume and network in the account. |
| `DescribeLogGroups` (`logs:DescribeLogGroups`) | No resource-level support. Lists log group names only. |
| `DescribeParameters` (`ssm:DescribeParameters`) | No resource-level support. Lists parameter names and types, never values. |
| `ListBackups` (`backup:List*`) | Not every Backup list action is resource-scoped. They disclose metadata only. |

`ReadTheBackups` names `backup-plan:*`: a backup plan's ARN holds a random ID,
not its name, so the plan role can read every backup plan in the region.
`ReadRoute53Changes` names `change/*`, because change IDs are random.

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
| name | Name of the managed policy, for example `acme-monitoring-ci-plan-monitoring-read`. | `string` | n/a | yes |
| name\_root | Prefix of resource names, in kebab-case. The monitoring stack names everything from `<name_root>-<project>`: roles, functions, schedules, alarms, the topic and the vault are `<name_root>-<project>` or `<name_root>-<project>-*`, parameters `/<name_root>-<project>/*`. | `string` | n/a | yes |
| project | Project name in kebab-case. Every resource ARN in the policy is built from `<name_root>-<project>`. | `string` | n/a | yes |
| zone\_id | Route 53 hosted zone of the node's record (the monitoring module's `zone_id`). Null: the stack has no record and the policy reads nothing in Route 53. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
