# compute/manage

Create and manage the shared infrastructure of a project that has a network (a
[`vpc`](https://registry.terraform.io/modules/jaws-platform/jaws-network/aws/latest/submodules/vpc))
but no [`container-instance`](https://registry.terraform.io/modules/jaws-platform/jaws-lichess-bot/aws/latest/submodules/container-instance):
its VPC, subnets, internet gateway, route table and security groups; its instance role,
instance profile and inline policy; and its log groups under
`/<name_root>/<project>/`. Class: **write**.

It is the network, instance role and log group part of
[`container/manage`](https://github.com/jaws-platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/container/manage). It starts and stops no instance,
touches no image repository, parameter or bucket, and attaches no managed
policy. Task instances are launched by [`task/launch`](https://github.com/jaws-platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/task/launch) on
the task role, never by this policy.

Write policies grant no reads; pair it with [`compute/read`](https://github.com/jaws-platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/compute/read) on the
apply role.

Part of the [`ci-policies`](https://registry.terraform.io/modules/jaws-platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["compute/manage"]`; it is not meant to be called directly.

## How it is scoped

- **EC2 by tag.** Create calls require `aws:RequestTag/Project = <project>`
  and every change or delete requires `aws:ResourceTag/Project = <project>`.
  This only works because the caller's provider `default_tags` carry
  `Project`, for example from the
  [`context`](https://registry.terraform.io/modules/jaws-platform/jaws-foundation/aws/latest/submodules/context)
  module. Security group rules created with tags are new
  `security-group-rule` resources and are authorised by their request tags.
  Creating a subnet, security group or route table also authorizes against
  the parent VPC, which must carry the same tag.
- **IAM by name.** Roles, instance profiles and policies are limited to
  `<name_root>-<project>-*`. `iam:PassRole` only passes project roles to EC2.
- **Log groups by path.** They live under `/<name_root>/<project>/`.

## Known gaps

| Statement | Why it is `*` |
|---|---|
| `CreateTagsOnCreate` (`ec2:CreateTags`) | Tags applied by a create call. Bounded with `ec2:CreateAction` to the create calls this policy allows, each of which already requires the `Project` tag. |
| `ManageProjectTags` (`ec2:CreateTags`, `ec2:DeleteTags`) | Tag changes on existing resources. Bounded by `aws:ResourceTag/Project`. |

## Known limitation

Like [`container/manage`](https://github.com/jaws-platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/container/manage), this policy can edit the
inline policies of `<name_root>-<project>-*` roles, including the project's
own CI roles if they share the prefix. `iam:PutRolePolicy` and
`iam:CreatePolicyVersion` do not limit the document, so a holder can rewrite
one of those roles or policies to grant anything in the account, not only
within the project's namespace. The only gate on that route is the protected
environment the apply role trusts, so protect it.

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
| name | Name of the managed policy, for example `acme-chess-bot-ci-apply-compute-manage`. | `string` | n/a | yes |
| name\_root | Prefix of resource names, in kebab-case. Roles, policies, repositories and buckets are scoped to `<name_root>-<project>-*`; parameters and log groups to `/<name_root>/<project>/*`. | `string` | n/a | yes |
| project | Project name in kebab-case. Every resource ARN in the policy is built from `<name_root>-<project>`. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
