# ci-release-role

Part of [`Jaws-Platform/jaws-ci/aws`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest) · [Registry](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-release-role) · [Source](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-release-role)

The IAM role an application repository's release workflow assumes through
GitHub OIDC to ship a container image and roll it out on a
[`container-instance`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest/submodules/container-instance):
build and push the image for the release tag to the project's
[`ecr-repository`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest/submodules/ecr-repository),
set the desired version and run the instance's reconciler. It trusts only
`repo:<repository>:ref:refs/tags/<tag_pattern>` (`v*` by default) and is
named `<name_root>-<project>-ci-release`. Built
from [`github-oidc-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/github-oidc-role) and
[`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies).

## Why release tags and not an environment

The apply roles trust a GitHub environment (`environment:prod`), which lets
a repository add required reviewers and branch rules. The release role
trusts tag refs instead:

- the repository needs no environment and no settings, only one workflow file;
- a branch, a pull request or a fork can never produce a `refs/tags/v*`
  token for the repository, so none of them can push an image;
- the trade-off is that anyone who can push a `v*` tag to the repository
  can release. Protect tags with a ruleset if more than the owner can push.

With `owner_id` and `repository_id` set (from `gh api users/<owner> --jq .id`
and `gh api repos/<owner>/<repo> --jq .id`), the role also trusts GitHub's
immutable subject form `repo:<owner>@<owner_id>/<name>@<repository_id>:...`.
The audience is pinned to `sts.amazonaws.com`.

## Permissions

The role has no permissions of its own. `policies` names managed policies
from the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog; this role accepts only
release and common policies: `container/release`, `ecr/pull`. Anything else
fails at plan time. `container/release` can push to the project's image
repository, write `/<name_root>/<project>/bot/*` parameters and run the
reconciler on instances tagged with the project; it can read no secret and
change no infrastructure.

## Usage

```hcl
module "chess_bot_release" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/ci-release-role"
  version = "0.1.3" # x-release-please-version

  name_root         = "acme"
  project           = "chess-bot"
  repository        = "acme/chess-bot"
  owner_id          = "12345678"  # gh api users/acme --jq .id
  repository_id     = "123456789" # gh api repos/acme/chess-bot --jq .id
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  policies = ["container/release"]
}
```

`data.aws_iam_openid_connect_provider.github` is the account's GitHub Actions
OIDC provider, looked up by its URL, `https://token.actions.githubusercontent.com`.
The [root README](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest) shows how to create it.

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
| name\_root | Prefix of the role and policy names, in kebab-case. The role is named `<name_root>-<project>-ci-release`. | `string` | n/a | yes |
| oidc\_provider\_arn | ARN of the account's GitHub Actions OIDC provider (`token.actions.githubusercontent.com`). | `string` | n/a | yes |
| policies | Managed policies to create and attach, by catalog name. This role accepts only release and common policies: `container/release`, `ecr/pull`. | `set(string)` | n/a | yes |
| project | Project in kebab-case, for example `chess-bot`. The role is named `<name_root>-<project>-ci-release`, and `container/release` is scoped to the project's repository, `/<name_root>/<project>/bot/*` parameters and instances tagged `Project = <project>`. | `string` | n/a | yes |
| repository | GitHub repository whose workflows may assume the role, as `owner/repo`. | `string` | n/a | yes |
| owner\_id | Numeric GitHub ID of the repository owner (`gh api users/<owner> --jq .id`). When set together with `repository_id`, the role also trusts GitHub's immutable subject form `repo:<owner>@<owner_id>/<name>@<repository_id>:...`. | `string` | `null` | no |
| policy\_inputs | Values the requested policies are built from, one optional section per policy family. `container/release` needs none; `ecr/pull` needs `ecr = { repository_arn }`. The `ci-policies` module checks the shape. | `any` | `{}` | no |
| repository\_id | Numeric GitHub ID of the repository (`gh api repos/<owner>/<repo> --jq .id`). When set together with `owner_id`, the role also trusts GitHub's immutable subject form. | `string` | `null` | no |
| tag\_pattern | Git tags whose workflows may assume the role, as a glob. The role trusts `ref:refs/tags/<tag_pattern>`; the default `v*` matches Release Please tags like `v1.2.3`. | `string` | `"v*"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| policy\_arns | Map of requested policy (for example `container/release`) to the ARN of the managed policy created for it and attached to the role. |
| role\_arn | ARN of the role, for `role-to-assume` in `aws-actions/configure-aws-credentials`. |
| role\_name | Name of the role. |
<!-- END_TF_DOCS -->
