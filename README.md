# terraform-aws-jaws-ci

[![Terraform Registry](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fregistry.terraform.io%2Fv1%2Fmodules%2FJaws-Platform%2Fjaws-ci%2Faws&query=%24.version&prefix=v&label=registry&logo=terraform&color=7B42BC)](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest)
[![GitHub release](https://img.shields.io/github/v/release/Jaws-Platform/terraform-aws-jaws-ci?label=release)](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/releases/latest)
[![CI](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/actions/workflows/ci.yml/badge.svg?event=pull_request)](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/blob/main/LICENSE)

AWS access for GitHub Actions workflows through OIDC, with **no long-lived
keys**: one IAM role per kind of job, each trusted for exactly the GitHub
events that run that job, and each holding only the managed policies it
requests from a catalog.

The root module creates the pair a repository that runs Terraform needs: a
**plan role** that any pull request can assume and that holds read policies
only, and an **apply role** that only jobs in one GitHub environment can
assume, which is where reviewers approve a change before it is applied. The
submodules add roles for pull request previews, releases and one-off tasks,
and a plain OIDC role for everything the catalog does not cover.

It is one of the [Jaws](https://github.com/jwallace145/jaws) module families,
and has no dependency on Jaws: everything is a plain input.

## What it creates

```text
 GitHub Actions run in acme/guitar            AWS account
 ─────────────────────────────────            ──────────────────────────────────────

                                              GitHub OIDC provider
                                              (one per account, not created here)
                                                    │ verifies the run's token
 pull request                                       ▼
   sub = repo:acme/guitar:pull_request ───────► acme-guitar-ci-plan
                                                  ├─ acme-guitar-ci-plan-tfstate-read
                                                  └─ acme-guitar-ci-plan-static-site-read

 job in the environment "prod"
   sub = repo:acme/guitar:environment:prod ───► acme-guitar-ci-apply
                                                  ├─ acme-guitar-ci-apply-tfstate-write
                                                  ├─ acme-guitar-ci-apply-static-site-read
                                                  └─ acme-guitar-ci-apply-static-site-deploy
```

Each role is one IAM role whose trust policy allows
`sts:AssumeRoleWithWebIdentity` from the account's GitHub OIDC provider, for
the audience `sts.amazonaws.com` and for the listed subjects only. Each entry
of a role's policy list becomes one customer-managed policy, built for that
project and role and attached to it. Nothing else is created: no users, no
access keys and no inline policies.

| Role | Created by | Trusts, after `repo:<owner>/<repo>:` | Accepts policies of class |
|---|---|---|---|
| `<name_root>-<project>-ci-plan` | root, `ci-plan-role` | `pull_request` | read, common |
| `<name_root>-<project>-ci-apply` | root, `ci-apply-role` | `environment:<environment>` | read, write, common |
| `<name_root>-<project>-ci-preview` | `ci-preview-role` | `pull_request` | preview, common |
| `<name_root>-<project>-ci-release` | `ci-release-role` | `ref:refs/tags/<tag_pattern>` | release, common |
| `<name_root>-<project>-ci-task` | `ci-task-role` | `pull_request`, `ref:refs/heads/main` | task, common |

A role that unreviewed code can assume cannot be given a write policy: a
request for a policy outside a role's classes fails at plan time.

## Modules

| Module | Creates |
|---|---|
| [root](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest) | The plan and apply roles of one project in one call, built from one set of `policy_inputs`. |
| [`ci-plan-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-plan-role) | The role pull request workflows assume to run `terraform plan`. Read policies only. |
| [`ci-apply-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-apply-role) | The role jobs in one GitHub environment assume to run `terraform apply` and publish. Read and write policies. |
| [`ci-preview-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-preview-role) | The role pull request workflows assume to publish a preview of a static site. It can write nothing but `previews/` in the site bucket. |
| [`ci-release-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-release-role) | The role a release tag's workflow assumes to push a container image and roll it out. It can change no infrastructure. |
| [`ci-task-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-task-role) | The role a workflow assumes to run one task on a dedicated, short-lived EC2 instance and terminate it. |
| [`github-oidc-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/github-oidc-role) | One role GitHub Actions assumes through OIDC, for any subjects, with your own inline and managed policies. The building block of the five above, and the module to use when the catalog does not fit. |
| [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) | The policy catalog: one managed policy per requested name, and the rules for which role may hold which. The role modules call it; it is rarely used directly. |

## The policy catalog

A policy is requested by name, `<family>/<name>`, and built from the matching
section of `policy_inputs`. Each family covers what one kind of stack needs:

| Family | Policies | For | `policy_inputs` section |
|---|---|---|---|
| `tfstate` | `read`, `write` | A stack's Terraform state in S3, for example in a [`tfstate-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/tfstate-bucket) | `tfstate = { bucket_arn, key or prefix }` |
| `static-site` | `read`, `deploy`, `previews` | A site built with [`jaws-static-site`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest): its [`site-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/site-bucket), distributions, certificates and records | `static_site = { bucket_arn, zone_id, record_names }` |
| `foundation` | `read`, `manage` | The stack that owns an account's shared resources: the state bucket, the hosted zone, and every `<name_root>-*` bucket, role, policy and image repository | `foundation = { state_bucket_arn, hosted_zone_arn }` |
| `ecr` | `pull`, `push` | Images in one repository, for example an [`ecr-repository`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest/submodules/ecr-repository) | `ecr = { repository_arn }` |
| `container` | `read`, `manage`, `release`, `schedule` | A container on one EC2 instance, built with [`jaws-lichess-bot`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest): its network, [`container-instance`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest/submodules/container-instance), image repository, parameters and logs | none required |
| `compute` | `read`, `manage` | The network, instance role and log groups of a project without such a container, for example a [`vpc`](https://registry.terraform.io/modules/Jaws-Platform/jaws-network/aws/latest/submodules/vpc) | none |
| `task` | `read`, `manage`, `launch` | One-off tasks on short-lived instances, built with [`task-runner`](https://registry.terraform.io/modules/Jaws-Platform/jaws-research/aws/latest/submodules/task-runner) | `task = { instance_types }` for `launch` |
| `dataset` | `read`, `manage` | The configuration of [`dataset-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-research/aws/latest/submodules/dataset-bucket) buckets, never their objects | `dataset = { bucket_names }` |
| `databricks` | `read`, `manage` | A Databricks workspace built with [`jaws-databricks`](https://registry.terraform.io/modules/Jaws-Platform/jaws-databricks/aws/latest), beyond what `compute` grants | `databricks = { secret_parameter_arn, events_object_arn }` |

The [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies)
README is the reference: what every policy grants, how it is scoped, and each
place where it has to use `*`.

## Usage

The roles name the account's GitHub Actions OIDC provider in their trust
policies. An account has one. Create it once, with administrator credentials,
in whichever configuration bootstraps the account:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
```

Everywhere else, look it up:

```hcl
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
```

The plan and apply roles of a static site project:

```hcl
module "ci" {
  source  = "Jaws-Platform/jaws-ci/aws"
  version = "0.1.3" # x-release-please-version

  name_root         = "acme"
  project           = "guitar"
  repository        = "acme/guitar"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  plan_policies  = ["tfstate/read", "static-site/read"]
  apply_policies = ["tfstate/write", "static-site/read", "static-site/deploy"]

  policy_inputs = {
    tfstate = {
      bucket_arn = "arn:aws:s3:::acme-tfstate"
      prefix     = "project=guitar/"
    }
    static_site = {
      bucket_arn   = "arn:aws:s3:::acme-guitar"
      zone_id      = "Z0123456789ABCDEFGHIJ"
      record_names = ["guitar.example.com", "*.preview.guitar.example.com"]
    }
  }
}
```

A workflow then assumes a role by its ARN. The job needs the `id-token`
permission, and the apply job must run in the environment the role trusts:

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  plan: # on pull_request
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/acme-guitar-ci-plan
          aws-region: us-east-1

  apply: # on a release
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/acme-guitar-ci-apply
          aws-region: us-east-1
```

Each submodule can also be used on its own, for example the preview role
beside the pair above:

```hcl
module "ci_preview" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/ci-preview-role"
  version = "0.1.3" # x-release-please-version

  name_root         = "acme"
  project           = "guitar"
  repository        = "acme/guitar"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  policies      = ["static-site/previews"]
  policy_inputs = { static_site = { bucket_arn = "arn:aws:s3:::acme-guitar" } }
}
```

Or a role with permissions of your own, when no catalog policy fits:

```hcl
module "docs_publisher" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/github-oidc-role"
  version = "0.1.3" # x-release-please-version

  name              = "acme-docs-publisher"
  description       = "publishes acme/docs from main"
  repository        = "acme/docs"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  subjects          = ["ref:refs/heads/main"]
  component         = "ci"

  inline_policies = {
    publish = {
      Version = "2012-10-17"
      Statement = [{
        Sid      = "WriteDocs"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::acme-docs/*"
      }]
    }
  }
}
```

## Examples

- [`static-site`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/examples/static-site):
  the plan, apply and preview roles of a static site repository.
- [`foundation`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/examples/foundation):
  the plan and apply roles of the stack that owns an account's shared
  resources, with one state key and another environment name.

## What to know before using it

- **The account needs GitHub's OIDC provider**, and nothing here creates it.
  Usage, above, shows how.
- **`us-east-1` only.** The policies that name regional resources use the
  provider's region or `us-east-1` itself (ACM certificates for CloudFront,
  image repositories, the S3 endpoint service).
- **The catalog follows one naming and tagging convention.** Its policies
  reach resources named `<name_root>-<project>-*`, parameters and log groups
  under `/<name_root>/<project>/`, and resources tagged `Project = <project>`.
  That is what the other Jaws families create when they are given the same
  names and the provider's `default_tags` carry `Project`. For resources named
  any other way, use `github-oidc-role` with your own policies.
- **Any pull request in the repository can assume the plan role**, and the
  preview and task roles: a branch pushed to the repository is enough, with
  no review. GitHub issues no OIDC token to pull requests from forks. So
  whatever `plan_policies` can read, every contributor with push access can
  read. `tfstate/read` includes the state itself, and with it any secret
  stored in the state.
- **The apply role is as safe as its GitHub environment.** Protect the
  environment with required reviewers and restrict its deployment branches.
  With `foundation/manage`, `container/manage` or `compute/manage` the role
  can edit roles and policies in its own namespace, itself included, so treat
  a compromise of that environment as a compromise of what the role manages
  (with `foundation/manage`, of the account).
- **Write policies grant no reads.** Terraform refreshes before it changes
  anything, so list the read policy next to each write policy in
  `apply_policies`: `static-site/read` with `static-site/deploy`, and so on.
  `tfstate/write` is the exception: it reads the state it writes.
- **State is locked with S3 lock files.** `tfstate/*` grant the `.tflock`
  object beside the state (`use_lockfile = true` in the S3 backend) and no
  DynamoDB permission.
- **IAM limits.** A role name is at most 64 characters, which leaves 55 for
  `<name_root>-<project>` with the plan and apply roles and 53 with the
  preview and release roles. Each requested policy is one managed policy, and
  IAM attaches at most 10 to a role unless the account's quota has been
  raised.
- **Renaming replaces.** `name_root` and `project` are part of every role and
  policy name. Changing either creates new roles with new ARNs, which the
  workflows must then be given.
- **`policy_inputs` is checked by `ci-policies`, loosely.** A missing section
  fails at plan time with a message that names it. An attribute the catalog
  does not know is dropped silently, so a misspelt optional attribute falls
  back to its default.
- **No cost.** IAM roles, policies and OIDC federation are free.
- **Providers are never configured here.** The caller configures `aws`.
- **Tags.** Roles get `Name` and `Component = ci`, policies `Component = ci`.
  Every other tag comes from the caller's provider `default_tags`; the modules
  take no tag map.

The submodule READMEs have the details: the trust policy and its two subject
forms, why releases trust tags rather than an environment, and the known
gaps and limitations of each policy.

## Development

See [CONTRIBUTING.md](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/blob/main/CONTRIBUTING.md)
for local setup, the commit and pull request rules, CI, and how releases work.
`scripts/check.sh` runs everything CI runs, with no AWS credentials.

## Root module reference

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
| apply | ./modules/ci-apply-role | n/a |
| plan | ./modules/ci-plan-role | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| apply\_policies | Policies of the apply role, by catalog name, for example `["tfstate/write", "static-site/read", "static-site/deploy"]`. It accepts `read`, `write` and `common` policies. Write policies grant no reads, so list the matching read policy too. | `set(string)` | n/a | yes |
| name\_root | Prefix of the role and policy names in kebab-case, usually a short name for the organisation such as `acme`. The roles are named `<name_root>-<project>-ci-plan` and `<name_root>-<project>-ci-apply`, and the policies that scope by name reach only resources named `<name_root>-<project>-*`. | `string` | n/a | yes |
| oidc\_provider\_arn | ARN of the account's GitHub Actions OIDC provider, `arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com`. An account has one; this module does not create it. | `string` | n/a | yes |
| plan\_policies | Policies of the plan role, by catalog name, for example `["tfstate/read", "static-site/read"]`. Any pull request in the repository can assume this role, so it accepts only `read` and `common` policies; the `ci-policies` module lists them. | `set(string)` | n/a | yes |
| project | Project in kebab-case, for example `guitar`. It is part of both role names, which must fit IAM's 64-character limit, and the policies that scope by tag reach only resources tagged `Project = <project>`. | `string` | n/a | yes |
| repository | GitHub repository whose workflows may assume the roles, as `owner/repo`. | `string` | n/a | yes |
| environment | GitHub environment whose jobs may assume the apply role: it trusts `repo:<repository>:environment:<environment>` and nothing else. Protect the environment with required reviewers and restrict its deployment branches. | `string` | `"prod"` | no |
| owner\_id | Numeric GitHub ID of the repository owner (`gh api users/<owner> --jq .id`). Set it together with `repository_id` and both roles also trust GitHub's immutable subject form, `repo:<owner>@<owner_id>/<name>@<repository_id>:...`. Null trusts the classic form only. | `string` | `null` | no |
| policy\_inputs | Values the policies of both roles are built from, one optional section per policy family, for example `tfstate = { bucket_arn, key or prefix }` and `static_site = { bucket_arn, zone_id, record_names }`. Only the sections the requested policies need are required. The `ci-policies` module documents every section and checks the shape; an attribute it does not know is dropped silently. | `any` | `{}` | no |
| repository\_aliases | Other names the same repository is trusted under, as `owner/repo`, for example its new name while it is being renamed. Each is trusted exactly like `repository`. Remove an alias once no workflow run can carry it. | `list(string)` | `[]` | no |
| repository\_id | Numeric GitHub ID of the repository (`gh api repos/<owner>/<repo> --jq .id`). Set it together with `owner_id`. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| apply\_policy\_arns | Map of each entry of `apply_policies` (for example `tfstate/write`) to the ARN of the managed policy created for it and attached to the apply role. |
| apply\_role\_arn | ARN of the apply role, for `role-to-assume` in `aws-actions/configure-aws-credentials` in jobs that run in `environment`. |
| apply\_role\_name | Name of the apply role, `<name_root>-<project>-ci-apply`. |
| plan\_policy\_arns | Map of each entry of `plan_policies` (for example `tfstate/read`) to the ARN of the managed policy created for it and attached to the plan role. |
| plan\_role\_arn | ARN of the plan role, for `role-to-assume` in `aws-actions/configure-aws-credentials` in pull request workflows. |
| plan\_role\_name | Name of the plan role, `<name_root>-<project>-ci-plan`. |
<!-- END_TF_DOCS -->

## License

[MIT](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/blob/main/LICENSE)
