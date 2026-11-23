# ci-policies

Part of [`Jaws-Platform/jaws-ci/aws`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest) · [Registry](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) · [Source](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies)

The catalog of managed policies that CI roles are built from. Callers normally
do not use this module directly:
[`ci-plan-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-plan-role),
[`ci-preview-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-preview-role),
[`ci-apply-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-apply-role),
[`ci-release-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-release-role)
and [`ci-task-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-task-role)
call it with their `policies` and `policy_inputs` and attach what it creates.

Each policy a caller requests becomes one customer-managed policy built for
that project and role, named
`<name_root>-<project>-ci-<role>-<family>-<name>`. A policy's name is also its
folder: `static-site/deploy` lives in [`static-site/deploy/`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/static-site/deploy).

## Usage

The role modules call the catalog for you. Call it directly to create the
policies without a role, for example to attach them to a role you build with
[`github-oidc-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/github-oidc-role):

```hcl
module "ci_policies" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/ci-policies"
  version = "0.5.0" # x-release-please-version

  name_root         = "acme"
  project           = "infra"
  role              = "plan"
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"

  policies = ["tfstate/read", "foundation/read"]

  policy_inputs = {
    tfstate = {
      bucket_arn = "arn:aws:s3:::acme-tfstate"
      key        = "project=infra/env=prod/infra-prod.tfstate"
    }
    foundation = {
      state_bucket_arn = "arn:aws:s3:::acme-tfstate"
      hosted_zone_arn  = "arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"
    }
  }
}
```

`role` decides which policies may be requested (see Allow-lists, below) and is
part of every policy name. The `arns` output maps each requested policy
to the ARN of the policy created for it, in the shape `managed_policies` of
`github-oidc-role` takes.

## Catalog

| Policy | Class | Grants | `policy_inputs` |
|---|---|---|---|
| [`tfstate/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/tfstate/read) | read | List the state prefix, read state, write and delete only `.tflock` | `tfstate = { bucket_arn, key \| prefix }` |
| [`tfstate/write`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/tfstate/write) | write | Read and write state, take and release the lock. State objects are never deleted. | `tfstate = { bucket_arn, key \| prefix }` |
| [`static-site/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/static-site/read) | read | Read the site bucket's configuration, the project's distributions, functions and certificates, and the hosted zone | `static_site = { bucket_arn, zone_id }` |
| [`static-site/deploy`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/static-site/deploy) | write | Create and manage the project's distributions, functions and certificates, change its records, publish `prod/` and `dev/` | `static_site = { bucket_arn, zone_id, record_names }` |
| [`static-site/previews`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/static-site/previews) | preview | List and write `previews/*` in the site bucket | `static_site = { bucket_arn }` |
| [`foundation/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/foundation/read) | read | Read the state bucket and managed buckets (not their objects), `<name_root>-*` roles and policies, the GitHub OIDC provider, the hosted zone and the listed services' service-linked roles | `foundation = { state_bucket_arn, hosted_zone_arn, managed_bucket_patterns?, service_linked_role_services? }` |
| [`foundation/manage`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/foundation/manage) | write | Configure the state bucket, manage buckets matching `managed_bucket_patterns` (not their objects), manage `<name_root>-*` roles, policies and ECR repositories, change records in the hosted zone, create and tag the listed services' service-linked roles (never delete them) | `foundation = { state_bucket_arn, hosted_zone_arn, managed_bucket_patterns?, attachable_policy_arns?, service_linked_role_services? }` |
| [`ecr/pull`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/ecr/pull) | common | Log in to ECR and pull images from each repository: one policy per repository (`ecr/pull`, then `ecr/pull-2`, ...) | `ecr = { repository_arn }` or `ecr = { repository_arns }` |
| [`ecr/push`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/ecr/push) | write | Log in to ECR and push images to each repository: one policy per repository (`ecr/push`, then `ecr/push-2`, ...) | `ecr = { repository_arn }` or `ecr = { repository_arns }` |
| [`container/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/container/read) | read | Describe EC2, read the project's instance role and policies, image repository, parameters, log groups and their events, and records bucket configuration | none |
| [`container/manage`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/container/manage) | write | Create and manage the project's VPC, instance, instance role, image repository, log groups and records bucket configuration; never their objects, never parameter values | `container = { attachable_policy_arns? }` (optional) |
| [`container/release`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/container/release) | release | Push images to the project's repository, write `/<name_root>/<project>/bot/*` parameters, run `AWS-RunShellScript` on instances tagged with the project and follow it | none |
| [`container/schedule`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/container/schedule) | write | Create, update and delete the project's EventBridge Scheduler schedules (`<name_root>-<project>-*`, default group) and pass its `*-scheduler` role to `scheduler.amazonaws.com` | none |
| [`compute/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/compute/read) | read | Describe EC2, read the project's instance role and policies, its log groups and their events | none |
| [`compute/manage`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/compute/manage) | write | Create and manage the project's VPC, instance role and log groups; never instances, image repositories, parameters or buckets | none |
| [`task/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/task/read) | read | Read the configuration of the project's task results bucket | none |
| [`task/manage`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/task/manage) | write | Create and manage the project's task launch template and task results bucket configuration; never its objects | none |
| [`task/launch`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/task/launch) | task | Launch task instances from the project's template (allow-listed types, Amazon images, project network), run `AWS-RunShellScript` on them, read their log group and results prefix, terminate them | `task = { instance_types }` |
| [`task/records`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/task/records) | task | Put objects under one prefix of one bucket, the task launcher's records of each run; never get, list or delete them | `task = { records = { bucket, prefix } }` |
| [`dataset/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/dataset/read) | read | Read the configuration of the project's dataset buckets; never their objects | `dataset = { bucket_names }` |
| [`dataset/manage`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/dataset/manage) | write | Create and configure the project's dataset buckets; never their objects | `dataset = { bucket_names }` |
| [`databricks/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/databricks/read) | read | Read the configuration of the `<p>-databricks-root` and `<p>-databricks-catalog` buckets, read and decrypt the one Databricks credential parameter, read the EC2 on-demand vCPU quota, append to the project's event log | `databricks = { secret_parameter_arn, events_object_arn }` |
| [`databricks/manage`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/databricks/manage) | write | Configure and empty (list and delete, never read or put) the two Databricks buckets; create and manage the S3 gateway endpoint and the NAT instance (`t4g`, `c7g`, `c8g` or `m7g`, `Component = nat-instance`) with its own interface and public IP, and replace routes to it; the credential and event log as in `databricks/read`. Roles come from `compute/manage` | `databricks = { secret_parameter_arn, events_object_arn }` |
| [`monitoring/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/read) | read | Describe EC2, read the monitoring stack's `<name_root>-<project>` and `<name_root>-<project>-*` roles and instance profile, its functions, schedules, log group tags, `/<name_root>-<project>/` parameters, config bucket (configuration and bundles), snapshot vault and plans, alarms, topic, the off-hours page's certificate, distribution and function and, with a `zone_id`, the node's hosted zone | `monitoring = { zone_id?, domain? }` (optional) |
| [`monitoring/node`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/node) | write | Create and manage the monitoring node's instance, data volume, security group and rules (tagged `Project = <project>`), every role of the stack and their inline policies, the node's instance profile; attach only `AWSBackupServiceRolePolicyForBackup` to the snapshots role; pass only the node's role to EC2 | none |
| [`monitoring/config`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/config) | write | Create and configure the node's config bucket and write its bundles, write the `/<name_root>-<project>/` parameters and, with `zone_id` and `domain`, change that one record | `monitoring = { zone_id?, domain? }` (optional) |
| [`monitoring/functions`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/functions) | write | Create and manage the normalizer and watchdog functions and their permission, their log groups, the watchdog topic and subscription, the status-check alarms and the stack's schedules; pass `<name_root>-<project>-*` roles to Lambda and EventBridge Scheduler | none |
| [`monitoring/backup`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/backup) | write | Create and manage the node's snapshot vault (with its default key, through AWS Backup), backup plan and selection; pass the snapshots role to AWS Backup | none |
| [`monitoring/off-hours-page`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/off-hours-page) | write | Request, tag and delete the node's off-hours page certificate (DNS-validated, for `domain` only), create and manage its CloudFront distribution and the function `<name_root>-<project>-off-hours-page` (all tagged `Project = <project>`), and change its CNAME validation record in the node's zone | `monitoring = { zone_id, domain }` (required) |

Each family covers what one kind of stack creates, and is scoped to the names
and tags the matching modules give their resources:

| Family | For |
|---|---|
| `tfstate/*` | A stack's Terraform state in a bucket such as [`tfstate-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/tfstate-bucket), locked with S3 lock files. |
| `static-site/*` | A site in a [`site-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/site-bucket), served by [`static-site`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/static-site) and [`preview-site`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/preview-site), with records in the zone of [`hosted-zone`](https://registry.terraform.io/modules/Jaws-Platform/jaws-static-site/aws/latest/submodules/hosted-zone). |
| `foundation/*` | An account's foundation stack: the one stack, typically applied once per account, that owns the state bucket, the hosted zone, every `<name_root>-*` bucket, role, policy and image repository (the CI roles included), and service-linked roles ([`service-linked-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/service-linked-role)). |
| `ecr/*` | Images in the listed repositories, one policy each, such as an [`ecr-repository`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest/submodules/ecr-repository). |
| `container/*` | A container on one EC2 instance: a [`container-instance`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest/submodules/container-instance) in its [`vpc`](https://registry.terraform.io/modules/Jaws-Platform/jaws-network/aws/latest/submodules/vpc), with its [`ecr-repository`](https://registry.terraform.io/modules/Jaws-Platform/jaws-lichess-bot/aws/latest/submodules/ecr-repository), parameters, log groups and records bucket. |
| `compute/*` | The [`vpc`](https://registry.terraform.io/modules/Jaws-Platform/jaws-network/aws/latest/submodules/vpc), instance role and log groups of a project without a `container-instance`. |
| `task/*` | One-off tasks on short-lived instances: a [`task-runner`](https://registry.terraform.io/modules/Jaws-Platform/jaws-research/aws/latest/submodules/task-runner) and its results bucket, and the records the launcher writes about each run. |
| `dataset/*` | The configuration of [`dataset-bucket`](https://registry.terraform.io/modules/Jaws-Platform/jaws-research/aws/latest/submodules/dataset-bucket) buckets. |
| `databricks/*` | A Databricks workspace built with the [`jaws-databricks`](https://registry.terraform.io/modules/Jaws-Platform/jaws-databricks/aws/latest) modules ([`databricks-workspace`](https://registry.terraform.io/modules/Jaws-Platform/jaws-databricks/aws/latest/submodules/databricks-workspace), [`databricks-catalog`](https://registry.terraform.io/modules/Jaws-Platform/jaws-databricks/aws/latest/submodules/databricks-catalog)) behind a [`nat-instance`](https://registry.terraform.io/modules/Jaws-Platform/jaws-network/aws/latest/submodules/nat-instance). |
| `monitoring/*` | The monitoring stack, the root module of [`jaws-monitoring`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest) with `name = "<name_root>-<project>"`: the [`billing-normalizer`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest/submodules/billing-normalizer) and the [`monitoring-node`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest/submodules/monitoring-node), with its off-hours schedule, watchdog, snapshots and optional record. |

`tfstate` takes exactly one of `key` (one stack's state object, for example
`project=infra/env=prod/infra-prod.tfstate`) or `prefix` (every object under a
project's prefix, for example `project=guitar/`).

Write policies grant no reads. The apply role needs the matching read policy
too, for refresh: `static-site/read` with `static-site/deploy`,
`foundation/read` with `foundation/manage`, `container/read` with
`container/manage` and `container/schedule`, `compute/read` with
`compute/manage`, `databricks/read` with `databricks/manage`, and
`monitoring/read` with `monitoring/node`, `monitoring/config`,
`monitoring/functions`, `monitoring/backup` and `monitoring/off-hours-page`.

The monitoring stack has five write policies, split by what they manage, so
each stays well inside the managed policy limit. They are written for the
stack's own names: the root module's `name` must be `<name_root>-<project>`,
and the owner's secrets (the Grafana credentials and Slack webhooks) must
live outside `/<name_root>-<project>/`, for example under
`/<name_root>/<project>/`. `monitoring/functions` may create the one
service-linked role its alarms' EC2 actions need
(`AWSServiceRoleForCloudWatchEvents`), because PutMetricAlarm asks for
`iam:CreateServiceLinkedRole` on every such alarm.

A Databricks workspace project holds `compute/*` and `databricks/*`
together: `compute/*` already covers its VPC, subnets, route tables, security
groups and `<name_root>-<project>-*` roles (the cross-account and Unity
Catalog roles included), and `databricks/*` adds only what the `vpc`
endpoint, `nat-instance`, `databricks-workspace` and `databricks-catalog`
modules need beyond that. Neither is split: `databricks/manage` is about
4,100 characters.

`compute/*` is for projects without a `container-instance`: the network,
instance role and log group statements of `container/*`, without its image
repository, instance, parameter and records bucket statements. `container/*` already holds what
`compute/*` grants, so a project needs one family, not both.

## Allow-lists

`role` decides which classes may be requested. The plan and preview roles
trust `pull_request`, so code that has not been reviewed can assume them; only
the apply role, which trusts a GitHub environment, may write. The release role
trusts an application repository's release tags: it may ship an image and
roll it out, and nothing that reads or changes the stack. The task role trusts
an application repository's pull requests and `main`: it may launch task instances
from the project's template and write the records of their runs, and nothing
else.

| Role | Accepts |
|---|---|
| `plan` | read, common |
| `preview` | preview, common |
| `apply` | read, write, common |
| `release` | release, common |
| `task` | task, common |

`common` policies are ones every role needs in order to run at all, such as
pulling the container image its jobs run in from ECR. They grant nothing a
pull request could misuse, which is why the preview role may have them
without accepting `read`.

A request outside the allow-list, an unknown policy name, or a policy without
its `policy_inputs` section fails at plan time with a message that names the
role, the policy and what is accepted.

## How permissions are scoped

- **Tags.** CloudFront distributions, CloudFront Functions and ACM certificates
  support `aws:ResourceTag`, and their create actions support
  `aws:RequestTag`. Those statements are conditioned on `Project = <project>`.
  This only works if the project's provider `default_tags` put the `Project`
  tag on every resource, which is what the `tags` output of the
  [`context`](https://registry.terraform.io/modules/Jaws-Platform/jaws-foundation/aws/latest/submodules/context)
  module is for.
- **Names.** CloudFront Function ARNs embed the function name, so
  `static-site/*` is further limited to `function/<name_root>-<project>-*`.
  The `static-site` and `preview-site` modules name their functions from
  `bucket_name`, so that input must be `<name_root>-<project>`: the name
  `site-bucket` gives the bucket.
- **Route 53.** `static-site/deploy` limits `ChangeResourceRecordSets` to the
  hosted zone and conditions it with
  `route53:ChangeResourceRecordSetsNormalizedRecordNames`
  (`ForAllValues:StringLike`) to `record_names`, plus `_*.<name>` for each of
  them so ACM DNS validation CNAMEs can be created. Wildcards are normalised
  to `\052` as Route 53 requires.
- **S3.** Object actions are limited to exact prefixes; `ListBucket` is
  conditioned on `s3:prefix`. The `foundation/*` policies name bucket ARNs
  only and never reach objects. The default pattern `<name_root>-*` matches
  the state bucket, so a grant on `<pattern>/*` would expose every project's
  state.
- **Names and paths (`container/*`, `compute/*`).** Roles, instance profiles, policies,
  the image repository and the records bucket are limited to
  `<name_root>-<project>` and `<name_root>-<project>-*`; parameters and log
  groups to `/<name_root>/<project>/`. EC2 is scoped by the `Project` tag:
  `aws:RequestTag/Project` on create, `aws:ResourceTag/Project` on change.
  `container/release` reaches only `/<name_root>/<project>/bot/*`, so the
  project's secret, kept beside `bot/`, is never readable by CI.
- **Names and tags (`monitoring/*`).** Roles are `<name_root>-<project>` (the
  node's, as is its instance profile) and `<name_root>-<project>-*`;
  functions, schedules, alarms, the topic and the snapshot vault are
  `<name_root>-<project>-*`; log groups `/aws/lambda/<name_root>-<project>-*`;
  parameters `/<name_root>-<project>/*`; the config bucket
  `<name_root>-<project>-config-<account>`. EC2 is scoped by the `Project`
  tag, as in `container/*`. Each `iam:PassRole` names its service: the node's
  role to EC2, `<name_root>-<project>-*` to Lambda and EventBridge Scheduler,
  the snapshots role to AWS Backup.
- **No `ReadOnlyAccess`.** That AWS-managed policy grants `s3:GetObject` on
  every bucket, including every project's state. `foundation/read` replaces it
  with the reads the foundation stack needs. If it misses an action, add the
  action to `foundation/read`.

### Known gaps (documented rather than silently granting `*`)

| Permission | Policy | Why it is `*` |
|---|---|---|
| `cloudfront:List*`, `acm:ListCertificates` | `static-site/read` | List actions have no resource-level or tag support. They only disclose metadata. |
| `cloudfront:Get*OriginAccessControl*`, `cloudfront:Get*CachePolicy*`, `cloudfront:GetResponseHeadersPolicy*` | `static-site/read` | Origin access controls, cache policies and response headers policies cannot be tagged and have random IDs, so they cannot be scoped to a project. |
| `cloudfront:*OriginAccessControl`, `cloudfront:*CachePolicy` | `static-site/deploy` | Same reason. The apply role can create, update and delete any OAC or custom cache policy in the account; it cannot touch distributions that are not tagged with the project. |
| `cloudfront:CreateDistribution`, `cloudfront:CreateFunction`, `acm:RequestCertificate` | `static-site/deploy` | Create actions take no resource ARN; they are conditioned on `aws:RequestTag/Project` instead. |
| `iam:ListOpenIDConnectProviders` | `foundation/read` | No resource-level support. Looking the provider up by URL lists them first. |
| `ecr:GetAuthorizationToken` | `ecr/pull`, `ecr/push` | No resource-level support. It only issues the Docker login token; what the token may pull or push is decided by the repository-scoped statements. |
| `route53:GetChange` on `change/*` | `static-site/read`, `foundation/*`, `monitoring/read` | Change IDs are random; this is read-only status polling. |
| `ec2:Describe*`, `logs:DescribeLogGroups`, `ssm:DescribeParameters` | `container/read`, `compute/read`, `monitoring/read` | No resource-level support. They disclose metadata only, never parameter values or log events. |
| `backup:List*` | `monitoring/read` | Not every Backup list action is resource-scoped. Metadata only. |
| `backup:Describe*` and `backup:Get*`, and the plan and selection actions, on `backup-plan:*` | `monitoring/read`, `monitoring/backup` | A backup plan's ARN holds a random ID, not its name, and selections are authorized against their plan. The apply role can change any backup plan in the region. |
| `backup-storage:MountCapsule` | `monitoring/backup` | `CreateBackupVault` needs it, and it has no resource-level support. |
| `kms:CreateGrant`, `kms:DescribeKey`, `kms:GenerateDataKey`, `kms:Decrypt`, `kms:RetireGrant` on `key/*` | `monitoring/backup` | The vault's default key `aws/backup` has a random ID. Conditioned on `kms:ViaService = backup.<region>.amazonaws.com`, so usable only through AWS Backup. |

`foundation/read` and `foundation/manage` also grant `s3:ListBucket` on the
state bucket. That lists every project's state keys, but does not read them.

### Known limitation: `foundation/manage` can edit `<name_root>-*` roles

The `ArnLike` allow-list on `iam:AttachRolePolicy` bounds which **managed**
policies can be attached; by default only `<name_root>-*` customer-managed
policies. It does not bound **inline** policies, trust policies or the
contents of `<name_root>-*` policies, which `foundation/manage` can create and
edit. It can also set the state bucket's policy. A role with
`foundation/manage` can therefore grant itself, or any `<name_root>-*` role,
more access. Treat a compromise of the environment that role trusts as a
compromise of the account: protect it with required reviewers and deployment
branches restricted to `main`.

## Policy descriptions are frozen

`description` on `aws_iam_policy` forces replacement. Replacing a policy
detaches it from every role that holds it until the new one is attached, and
when the role doing the apply holds it, the apply can lose its own
permissions partway through. Every leaf therefore pins its description in a
test. Describe what a policy grants in its README, never in the description.

## Adding a policy

1. Create `<family>/<name>/` with `main.tf` (one `aws_iam_policy.this`),
   `variables.tf`, `outputs.tf` (`arn`, `name`, `policy`), `versions.tf`,
   `README.md` and `tests/`. Leaves are internal, so they have no
   `examples/basic`.
2. Add `"<family>/<name>" = "<class>"` to `local.catalog` in `main.tf`.
3. Add a `module` block for it in `main.tf` and an entry in `local.created`
   in `outputs.tf`.
4. If it needs new inputs, add an optional section or attribute to
   `policy_inputs` and a validation on `policies` that requires it.

The role modules need no change beyond the list of accepted policies in their
`policies` description, plus the allow-list that `ci-release-role` and
`ci-task-role` mirror for a release or task policy. CI needs none:
[`scripts/list-modules.sh`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/blob/main/scripts/list-modules.sh)
finds every directory under `modules/` that has a `versions.tf`, so the new
leaf is checked as soon as it exists.

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
| compute\_manage | ./compute/manage | n/a |
| compute\_read | ./compute/read | n/a |
| container\_manage | ./container/manage | n/a |
| container\_read | ./container/read | n/a |
| container\_release | ./container/release | n/a |
| container\_schedule | ./container/schedule | n/a |
| databricks\_manage | ./databricks/manage | n/a |
| databricks\_read | ./databricks/read | n/a |
| dataset\_manage | ./dataset/manage | n/a |
| dataset\_read | ./dataset/read | n/a |
| ecr\_pull | ./ecr/pull | n/a |
| ecr\_pull\_extra | ./ecr/pull | n/a |
| ecr\_push | ./ecr/push | n/a |
| ecr\_push\_extra | ./ecr/push | n/a |
| foundation\_manage | ./foundation/manage | n/a |
| foundation\_read | ./foundation/read | n/a |
| monitoring\_backup | ./monitoring/backup | n/a |
| monitoring\_config | ./monitoring/config | n/a |
| monitoring\_functions | ./monitoring/functions | n/a |
| monitoring\_node | ./monitoring/node | n/a |
| monitoring\_off\_hours\_page | ./monitoring/off-hours-page | n/a |
| monitoring\_read | ./monitoring/read | n/a |
| static\_site\_deploy | ./static-site/deploy | n/a |
| static\_site\_previews | ./static-site/previews | n/a |
| static\_site\_read | ./static-site/read | n/a |
| task\_launch | ./task/launch | n/a |
| task\_manage | ./task/manage | n/a |
| task\_read | ./task/read | n/a |
| task\_records | ./task/records | n/a |
| tfstate\_read | ./tfstate/read | n/a |
| tfstate\_write | ./tfstate/write | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name\_root | Prefix of every policy name, in kebab-case. Policies are named `<name_root>-<project>-ci-<role>-<family>-<name>`. | `string` | n/a | yes |
| oidc\_provider\_arn | ARN of the account's GitHub Actions OIDC provider, which `foundation/read` may read. | `string` | n/a | yes |
| policies | Policies to create, from the catalog: `tfstate/read`, `tfstate/write`, `static-site/read`, `static-site/deploy`, `static-site/previews`, `foundation/read`, `foundation/manage`, `ecr/pull`, `ecr/push`, `container/read`, `container/manage`, `container/release`, `container/schedule`, `compute/read`, `compute/manage`, `task/read`, `task/manage`, `task/launch`, `task/records`, `dataset/read`, `dataset/manage`, `databricks/read`, `databricks/manage`, `monitoring/read`, `monitoring/node`, `monitoring/config`, `monitoring/functions`, `monitoring/backup`, `monitoring/off-hours-page`. Each role accepts only some of them; see the README. | `set(string)` | n/a | yes |
| project | Project in kebab-case, for example `guitar` or `infra`. Used in policy names and as the `Project` tag value static-site policies are scoped to. | `string` | n/a | yes |
| role | The CI role the policies are for: `plan`, `preview`, `apply`, `release` or `task`. It decides which policies may be requested. | `string` | n/a | yes |
| policy\_inputs | Values the requested policies are built from, one optional section per policy family. `tfstate` takes `bucket_arn` and exactly one of `key` or `prefix`. `static_site` takes `bucket_arn`, plus `zone_id` for `read` and `deploy` and `record_names` for `deploy`. `foundation` takes `state_bucket_arn`, `hosted_zone_arn` and optionally `managed_bucket_patterns`, `attachable_policy_arns` and `service_linked_role_services` (the AWS services whose service-linked role the stack owns, for example `["spot.amazonaws.com"]`). `ecr` takes exactly one of `repository_arn` (one repository) or `repository_arns` (a non-empty list; the first repository gets `ecr/pull` and the n-th from the second on gets `ecr/pull-<n>`, likewise `ecr/push-<n>`, each its own managed policy). `container` optionally takes `attachable_policy_arns` for `container/manage`; `task` takes `instance_types` and optionally `profiles` (default `["cpu"]`) for `task/launch`, and `records = { bucket, prefix }` for `task/records` (the bucket's name and the key prefix, without a leading or trailing slash, the records are written under); `dataset` takes `bucket_names` for the `dataset/*` policies; `databricks` takes `secret_parameter_arn` (the one SSM parameter holding the Databricks credential) and `events_object_arn` (`arn:aws:s3:::<audit bucket>/events/project=<project>/*`) for the `databricks/*` policies; `monitoring` optionally takes `zone_id` and `domain` together, the monitoring node's hosted zone and record, for `monitoring/read` and `monitoring/config`, and requires them for `monitoring/off-hours-page`; the `container/*` policies are otherwise built from `project` alone, and the `compute/*` and other `monitoring/*` policies entirely. | <pre>object({<br/>    tfstate = optional(object({<br/>      bucket_arn = string<br/>      key        = optional(string)<br/>      prefix     = optional(string)<br/>    }))<br/>    static_site = optional(object({<br/>      bucket_arn   = string<br/>      zone_id      = optional(string)<br/>      record_names = optional(list(string))<br/>    }))<br/>    foundation = optional(object({<br/>      state_bucket_arn             = string<br/>      hosted_zone_arn              = string<br/>      managed_bucket_patterns      = optional(list(string))<br/>      attachable_policy_arns       = optional(list(string))<br/>      service_linked_role_services = optional(list(string))<br/>    }))<br/>    ecr = optional(object({<br/>      repository_arn  = optional(string)<br/>      repository_arns = optional(list(string))<br/>    }))<br/>    container = optional(object({<br/>      attachable_policy_arns = optional(list(string))<br/>    }))<br/>    task = optional(object({<br/>      instance_types = optional(list(string))<br/>      profiles       = optional(list(string), ["cpu"])<br/>      records = optional(object({<br/>        bucket = string<br/>        prefix = string<br/>      }))<br/>    }))<br/>    dataset = optional(object({<br/>      bucket_names = list(string)<br/>    }))<br/>    databricks = optional(object({<br/>      secret_parameter_arn = string<br/>      events_object_arn    = string<br/>    }))<br/>    monitoring = optional(object({<br/>      zone_id = optional(string)<br/>      domain  = optional(string)<br/>    }))<br/>  })</pre> | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arns | Map of requested policy (for example `static-site/read`) to the ARN of the managed policy created for it. |
| documents | Map of requested policy to its policy document as a JSON string. |
| names | Map of requested policy to the name of the managed policy created for it. |
<!-- END_TF_DOCS -->
