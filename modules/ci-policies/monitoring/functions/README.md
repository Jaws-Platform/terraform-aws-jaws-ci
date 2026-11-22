# monitoring/functions

Manage the serverless parts of the monitoring stack, the root module of
[`jaws-monitoring`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest):
the normalizer
([`billing-normalizer`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest/submodules/billing-normalizer))
and the node's watchdog
([`monitoring-node`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest/submodules/monitoring-node)),
with their log groups under `/aws/lambda/<name_root>-<project>-*`; the
watchdog's SNS topic, its subscription and the function's permission for it;
the two status-check alarms; and the EventBridge Scheduler schedules (the
node's start and stop, the watchdog's and the normalizer's, in the default
group). It passes the stack's `<name_root>-<project>-*` roles to
`lambda.amazonaws.com` and `scheduler.amazonaws.com` only. Class: **write**.

The roles themselves are created with
[`monitoring/node`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/node),
which manages every role of the stack. Write policies grant no reads; pair it
with [`monitoring/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/read)
on the apply role. The one exception is `lambda:GetLayerVersion` on the AWS
SDK for pandas layer: `CreateFunction` and `UpdateFunctionConfiguration` need
it for every layer a function uses. A `pandas_layer_arn` other than the
normalizer's default needs that grant for its own layer.

Part of the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["monitoring/functions"]`; it is not meant to be called
directly.

## Before the first apply

The alarms recover and reboot the node (`arn:aws:automate:<region>:ec2:recover`
and `:reboot`). CloudWatch runs those actions with the account's
`AWSServiceRoleForCloudWatchEvents` service-linked role
(`events.amazonaws.com`), and PutMetricAlarm with an EC2 action needs
`iam:CreateServiceLinkedRole` for every such alarm, whether or not the role
exists yet. So this policy may create that one role, and nothing else
(`CreateTheAlarmActionsRole`).

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
| name | Name of the managed policy, for example `acme-monitoring-ci-apply-monitoring-functions`. | `string` | n/a | yes |
| name\_root | Prefix of resource names, in kebab-case. The monitoring stack names everything from `<name_root>-<project>`: roles, functions, schedules, alarms, the topic and the vault are `<name_root>-<project>` or `<name_root>-<project>-*`, parameters `/<name_root>-<project>/*`. | `string` | n/a | yes |
| project | Project name in kebab-case. Every resource ARN in the policy is built from `<name_root>-<project>`. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
