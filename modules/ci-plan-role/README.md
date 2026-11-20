# ci-plan-role

Part of [`Jaws-Platform/jaws-ci/aws`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest) · [Registry](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-plan-role) · [Source](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-plan-role)

The IAM role a repository's pull request workflows assume through GitHub OIDC
to run `terraform plan`. It trusts `repo:<repository>:pull_request` and is
named `<name_root>-<project>-ci-plan`. Built from
[`github-oidc-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/github-oidc-role) and [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies).

With `owner_id` and `repository_id` set (from `gh api users/<owner> --jq .id`
and `gh api repos/<owner>/<repo> --jq .id`), the role also trusts GitHub's
immutable subject form `repo:<owner>@<owner_id>/<name>@<repository_id>:...`.
The audience is pinned to `sts.amazonaws.com`.

## Permissions

The role has no permissions of its own. `policies` names managed policies from
the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog; each one is created for this
project and role as `<name_root>-<project>-ci-plan-<family>-<name>` and
attached. `policy_inputs` carries the values they are built from, one optional
section per policy family; only the sections the requested policies need are
required. The catalog README lists every policy, what it grants and the inputs
it needs.

This role accepts only read and common policies: `tfstate/read`,
`static-site/read`, `foundation/read`, `container/read`, `compute/read`,
`task/read`, `dataset/read`, `databricks/read` and `ecr/pull`. Anything else
fails at plan time. Any pull request branch in the repository can assume the
role, so it must never be able to write.

`policy_inputs` is passed through as `any` and typed by `ci-policies`. A
section or attribute it does not know is dropped silently, so a misspelt
optional attribute (for example `managed_bucket_pattern`) falls back to its
default.

## Usage

```hcl
module "ci_plan" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/ci-plan-role"
  version = "0.1.2" # x-release-please-version

  name_root         = "acme"
  project           = "guitar"
  repository        = "acme/guitar"
  owner_id          = "12345678"  # gh api users/acme --jq .id
  repository_id     = "123456789" # gh api repos/acme/guitar --jq .id
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  policies = ["tfstate/read", "static-site/read"]

  policy_inputs = {
    tfstate     = { bucket_arn = module.state_bucket.arn, prefix = "project=guitar/" }
    static_site = { bucket_arn = module.site_bucket.arn, zone_id = module.zone.zone_id }
  }
}
```

`module.state_bucket`, `module.site_bucket` and `module.zone` are the
[`tfstate-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/tfstate-bucket),
[`site-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/site-bucket)
and [`hosted-zone`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/hosted-zone)
modules; any bucket ARN and zone ID will do.

`data.aws_iam_openid_connect_provider.github` is the account's GitHub Actions
OIDC provider, looked up by its URL, `https://token.actions.githubusercontent.com`.
The [root README](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest) shows how to create it.

For the stack that owns an account's shared resources (the state bucket, the
hosted zone, and every project's buckets, roles and policies), which is
typically applied once per account:

```hcl
module "infra_ci_plan" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/ci-plan-role"
  version = "0.1.2" # x-release-please-version

  name_root         = "acme"
  project           = "infra"
  repository        = "acme/acme-infra"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  policies = ["tfstate/read", "foundation/read"]

  policy_inputs = {
    tfstate    = { bucket_arn = module.state_bucket.arn, key = "project=infra/env=prod/infra-prod.tfstate" }
    foundation = { state_bucket_arn = module.state_bucket.arn, hosted_zone_arn = module.zone.arn }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.11 |
| aws | ~> 6.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| policies | ../ci-policies | n/a |
| role | ../github-oidc-role | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name\_root | Prefix of the role and policy names, in kebab-case. The role is named `<name_root>-<project>-ci-plan`. | `string` | n/a | yes |
| oidc\_provider\_arn | ARN of the account's GitHub Actions OIDC provider (`token.actions.githubusercontent.com`). | `string` | n/a | yes |
| policies | Managed policies to create and attach, by catalog name. This role accepts only read and common policies: `tfstate/read`, `static-site/read`, `foundation/read`, `container/read`, `compute/read`, `task/read`, `dataset/read`, `databricks/read`, `ecr/pull`. | `set(string)` | n/a | yes |
| project | Project in kebab-case, for example `guitar` or `infra`. The role is named `<name_root>-<project>-ci-plan`, and static-site policies are scoped to resources tagged `Project = <project>`. | `string` | n/a | yes |
| repository | GitHub repository whose workflows may assume the role, as `owner/repo`. | `string` | n/a | yes |
| owner\_id | Numeric GitHub ID of the repository owner (`gh api users/<owner> --jq .id`). When set together with `repository_id`, the role also trusts GitHub's immutable subject form `repo:<owner>@<owner_id>/<name>@<repository_id>:...`. | `string` | `null` | no |
| policy\_inputs | Values the requested policies are built from, one optional section per policy family, for example `tfstate = { bucket_arn, key or prefix }`, `static_site = { bucket_arn, zone_id?, record_names? }` and `foundation = { state_bucket_arn, hosted_zone_arn }`. Only the sections the requested policies need are required. The `ci-policies` module documents every section and checks the shape. | `any` | `{}` | no |
| repository\_aliases | Other names the same repository is trusted under, as `owner/repo`, for example its new name while it is being renamed. Each is trusted exactly like `repository`, with the same `owner_id` and `repository_id`. Remove an alias once no workflow run can carry it. | `list(string)` | `[]` | no |
| repository\_id | Numeric GitHub ID of the repository (`gh api repos/<owner>/<repo> --jq .id`). When set together with `owner_id`, the role also trusts GitHub's immutable subject form. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| policy\_arns | Map of requested policy (for example `static-site/read`) to the ARN of the managed policy created for it and attached to the role. |
| role\_arn | ARN of the role, for `role-to-assume` in `aws-actions/configure-aws-credentials`. |
| role\_name | Name of the role. |
<!-- END_TF_DOCS -->
