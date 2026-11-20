# foundation/read

Read access for an account's foundation stack, replacing `ReadOnlyAccess`: the state
bucket's and managed buckets' configuration (never their objects),
`<name_root>-*` roles and policies, the GitHub OIDC provider, the hosted
zone and, for each service in `service_linked_role_services`, that service's
service-linked role. Class: **read**.

An account's foundation stack is the one stack, typically applied once per
account, that owns its shared resources: the state bucket
([`tfstate-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/tfstate-bucket)),
the hosted zone
([`hosted-zone`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/hosted-zone)),
the projects' buckets (each
[`site-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/site-bucket),
for example), the `<name_root>-*` roles and policies, the CI roles included,
and any service-linked role it creates with
[`service-linked-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/service-linked-role).

Part of the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["foundation/read"]`; it is not meant to be called directly.

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

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| hosted\_zone\_arn | ARN of the hosted zone the foundation stack manages (output `arn` of `hosted-zone`). | `string` | n/a | yes |
| name | Name of the managed policy, for example `acme-infra-ci-plan-foundation-read`. | `string` | n/a | yes |
| name\_root | Prefix of every role, policy and bucket the foundation stack manages, in kebab-case. | `string` | n/a | yes |
| oidc\_provider\_arn | ARN of the account's GitHub Actions OIDC provider. The policy may read it, so a data source can look it up. | `string` | n/a | yes |
| state\_bucket\_arn | ARN of the Terraform state bucket (output `arn` of `tfstate-bucket`). | `string` | n/a | yes |
| managed\_bucket\_patterns | Bucket name patterns the foundation stack manages. Defaults to `["<name_root>-*"]`, which covers every `site-bucket`. The policies reach the buckets themselves, never their objects. | `list(string)` | `null` | no |
| service\_linked\_role\_services | AWS services whose service-linked role the foundation stack owns, for example `["spot.amazonaws.com"]` (the `service-linked-role` module). Empty, the default, adds no statement. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
