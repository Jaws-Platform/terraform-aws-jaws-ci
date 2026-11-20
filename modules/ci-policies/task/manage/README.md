# task/manage

Create and manage the launch template of a project's
[`task-runner`](https://registry.terraform.io/modules/jwallace145/jaws-research/aws/latest/submodules/task-runner)
(by the `Project` tag) and the configuration of its task results bucket (by
name, never its objects). The task instance role, instance profile, security group and log
group are covered by [`container/manage`](https://github.com/jwallace145/terraform-aws-jaws-ci/tree/main/modules/ci-policies/container/manage). Class:
**write**; pair it with [`task/read`](https://github.com/jwallace145/terraform-aws-jaws-ci/tree/main/modules/ci-policies/task/read).

Part of the [`ci-policies`](https://registry.terraform.io/modules/jwallace145/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["task/manage"]`; it is not meant to be called directly.

## Known gaps

| Statement | Why it is `*` |
|---|---|
| `TagLaunchTemplateOnCreate` (`ec2:CreateTags`) | Tags applied by `CreateLaunchTemplate`. Bounded with `ec2:CreateAction` to that call, which itself requires the `Project` tag. |

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
| name | Name of the managed policy, for example `acme-chess-bot-ci-apply-task-manage`. | `string` | n/a | yes |
| name\_root | Prefix of resource names, in kebab-case. Roles, policies, repositories and buckets are scoped to `<name_root>-<project>-*`; parameters and log groups to `/<name_root>/<project>/*`. | `string` | n/a | yes |
| project | Project name in kebab-case. Every resource ARN in the policy is built from `<name_root>-<project>`. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
