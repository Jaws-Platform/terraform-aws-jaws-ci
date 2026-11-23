# ci-task-role

Part of [`Jaws-Platform/jaws-ci/aws`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest) · [Registry](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-task-role) · [Source](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-task-role)

The IAM role an application repository's workflows assume through GitHub OIDC
to run one task on a dedicated, ephemeral EC2 instance: launch it from the
project's [`task-runner`](https://registry.terraform.io/modules/Jaws-Platform/jaws-research/aws/latest/submodules/task-runner)
launch template, run the task through SSM Run Command, read
its output and results, and terminate it. It trusts the repository's pull
requests and its `main` branch by default and is named
`<name_root>-<project>-ci-task`. Built from
[`github-oidc-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/github-oidc-role) and
[`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies).

## Who can assume it

The trust lists exact subjects, never globs: `repo:<repository>:pull_request`
and `repo:<repository>:ref:refs/heads/main` by default. `subjects` may
replace them, but each must be `pull_request` or `ref:refs/heads/<branch>`;
tags, environments and wildcards fail at plan time.

- **Forks cannot reach it.** GitHub issues no OIDC token to pull request
  runs from forks, so `pull_request` admits same-repository pull requests
  only.
- **Anyone who can push a branch can open a pull request** and so launch
  task instances. The role bounds what they can launch, not whether.
- **`ref:refs/heads/main` is shared by other events.** GitHub gives the same
  subject to `pull_request_target`, `issue_comment`, `workflow_run` and
  `schedule` runs on `main`, and IAM cannot tell them apart. A workflow on
  `main` that runs one of those events and checks out pull request code
  would hand a fork the role. Keep such workflows from assuming it, protect
  `.github/workflows` with CODEOWNERS, and have the task workflow refuse
  any event other than `pull_request`, `push` and `workflow_dispatch`.

With `owner_id` and `repository_id` set (from `gh api users/<owner> --jq .id`
and `gh api repos/<owner>/<repo> --jq .id`), the role also trusts GitHub's
immutable subject form `repo:<owner>@<owner_id>/<name>@<repository_id>:...`.
The audience is pinned to `sts.amazonaws.com`.

## Permissions

The role has no permissions of its own. `policies` names managed policies
from the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog; this role accepts only
task and common policies: `task/launch`, `task/records`, `ecr/pull`.
Anything else fails at plan time. `task/launch` can launch only from the
project's launch template, only the listed instance types, only Amazon-owned
images, only into the project's subnets and security groups, and only with
`Purpose = ci-task`.
It can terminate and send commands only to instances tagged with the
project and `Purpose = ci-task`, so long-lived instances such as a
[`container-instance`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest/submodules/container-instance)
are out of reach. It can read no secret and change no infrastructure.

`task/records` lets the launcher write its records of each run, for example
one JSON object per task-run event, and nothing else: `s3:PutObject` under one
prefix of one bucket, never a get, list or delete. Request it beside
`task/launch` with the bucket's name and the key prefix, which has no leading
or trailing slash:

```hcl
  policies = ["task/launch", "task/records"]
  policy_inputs = {
    task = {
      instance_types = ["c8a.xlarge", "c8a.2xlarge"]
      records = {
        bucket = "acme-billing-123456789012"
        prefix = "raw/provider=acme/source=task-runs/project=chess-bot"
      }
    }
  }
```

## Session length

The job that runs a task (in Jaws, the CLI's `task run` command) holds one
role session for the whole task, so the role allows sessions of
`max_session_duration`, 7 hours by default. That covers the default 6-hour
task cap of `task-runner` plus launch and setup. The workflow requests a
session sized to the task with `role-duration-seconds`. A one-hour session
would expire mid-task and leave the job unable to stream output, copy
results or terminate the instance.

## Usage

```hcl
module "chess_bot_task" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/ci-task-role"
  version = "0.4.0" # x-release-please-version

  name_root         = "acme"
  project           = "chess-bot"
  repository        = "acme/chess-bot"
  owner_id          = "12345678"  # gh api users/acme --jq .id
  repository_id     = "123456789" # gh api repos/acme/chess-bot --jq .id
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  policies = ["task/launch"]
  policy_inputs = {
    task = { instance_types = ["c8a.xlarge", "c8a.2xlarge"] }
  }
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
| name\_root | Prefix of the role and policy names, in kebab-case. The role is named `<name_root>-<project>-ci-task`. | `string` | n/a | yes |
| oidc\_provider\_arn | ARN of the account's GitHub Actions OIDC provider (`token.actions.githubusercontent.com`). | `string` | n/a | yes |
| policies | Managed policies to create and attach, by catalog name. This role accepts only task and common policies: `task/launch`, `task/records`, `ecr/pull`. | `set(string)` | n/a | yes |
| project | Project in kebab-case, for example `chess-bot`. The role is named `<name_root>-<project>-ci-task`, and `task/launch` is scoped to the project's launch templates, network, task role and instances tagged `Project = <project>` and `Purpose = ci-task`. | `string` | n/a | yes |
| repository | GitHub repository whose workflows may assume the role, as `owner/repo`. | `string` | n/a | yes |
| max\_session\_duration | Maximum session duration in seconds. The job that runs a task holds one session for the whole of it, so the session must outlast the project's longest task (`max_hours` of the `task-runner` module) plus launch and setup. The default, 7 hours, covers the default 6-hour cap; raise it, to at most 12 hours, for longer tasks. | `number` | `25200` | no |
| owner\_id | Numeric GitHub ID of the repository owner (`gh api users/<owner> --jq .id`). When set together with `repository_id`, the role also trusts GitHub's immutable subject form `repo:<owner>@<owner_id>/<name>@<repository_id>:...`. | `string` | `null` | no |
| policy\_inputs | Values the requested policies are built from, one optional section per policy family. `task/launch` needs `task = { instance_types }`, plus `profiles` when the project has more than the `cpu` profile; `task/records` needs `task = { records = { bucket, prefix } }`, the bucket's name and the key prefix the records are written under; `ecr/pull` needs `ecr = { repository_arn }` (or `ecr = { repository_arns }` for several repositories, one policy each). The `ci-policies` module checks the shape. | `any` | `{}` | no |
| repository\_id | Numeric GitHub ID of the repository (`gh api repos/<owner>/<repo> --jq .id`). When set together with `owner_id`, the role also trusts GitHub's immutable subject form. | `string` | `null` | no |
| subjects | GitHub OIDC subjects, after `repo:<repository>:`, whose workflows may assume the role. The default trusts the repository's pull requests and its `main` branch. GitHub issues no OIDC token to pull request runs from forks, so `pull_request` admits same-repository pull requests only. Each subject is exact: `pull_request` or `ref:refs/heads/<branch>`, with no wildcards. | `list(string)` | <pre>[<br/>  "pull_request",<br/>  "ref:refs/heads/main"<br/>]</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| max\_session\_duration | Maximum session duration of the role, in seconds; the workflow's `role-duration-seconds` must not exceed it. |
| policy\_arns | Map of requested policy (for example `task/launch`) to the ARN of the managed policy created for it and attached to the role. |
| role\_arn | ARN of the role, for `role-to-assume` in `aws-actions/configure-aws-credentials`. |
| role\_name | Name of the role. |
<!-- END_TF_DOCS -->
