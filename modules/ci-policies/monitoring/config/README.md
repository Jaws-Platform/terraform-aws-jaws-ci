# monitoring/config

Manage what configures the monitoring node of
[`jaws-monitoring`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest)
([`monitoring-node`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest/submodules/monitoring-node)):
its config bucket `<name_root>-<project>-config-<account>` (the bucket,
ownership controls, public access block, versioning, encryption and
lifecycle) and the bundles in it, its parameters under
`/<name_root>-<project>/` (`node/config-bundle`, `node/status`,
`node/running-config`), and, with `zone_id` and `domain`, the node's one
DNS record. Class: **write**.

Write policies grant no reads; pair it with
[`monitoring/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/read)
on the apply role.

Part of the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["monitoring/config"]` and, when the node has a record,
`policy_inputs = { monitoring = { zone_id, domain } }`; it is not meant to be
called directly.

## How it is scoped

- **The bucket by name.** Every bucket and object action names
  `<name_root>-<project>-config-<account>`. A bundle is named by its content,
  so each change replaces one; in the versioned bucket the provider deletes
  every version of the old key, hence `s3:DeleteObjectVersion` (and
  `s3:ListBucketVersions` in `monitoring/read`).
- **Parameters by path.** `/<name_root>-<project>/*` only. The owner's secrets
  (the Grafana credentials and Slack webhooks) must live elsewhere, for
  example under `/<name_root>/<project>/`, so the apply role can never
  overwrite them.
- **Route 53 by record name.** `ChangeResourceRecordSets` is limited to the
  hosted zone and conditioned with
  `route53:ChangeResourceRecordSetsNormalizedRecordNames`
  (`ForAllValues:StringEquals`) to `domain`, lowercased and without a trailing
  dot. Without `zone_id` and `domain` there is no Route 53 statement.

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
| name | Name of the managed policy, for example `acme-monitoring-ci-apply-monitoring-config`. | `string` | n/a | yes |
| name\_root | Prefix of resource names, in kebab-case. The monitoring stack names everything from `<name_root>-<project>`: roles, functions, schedules, alarms, the topic and the vault are `<name_root>-<project>` or `<name_root>-<project>-*`, parameters `/<name_root>-<project>/*`. | `string` | n/a | yes |
| project | Project name in kebab-case. Every resource ARN in the policy is built from `<name_root>-<project>`. | `string` | n/a | yes |
| domain | The node's record (the monitoring module's `domain`), for example `grafana.example.com`. With `zone_id`, the policy may change that one record in that zone. Null, with a null `zone_id`: the stack has no record and the policy changes nothing in Route 53. | `string` | `null` | no |
| zone\_id | Route 53 hosted zone of the node's record (the monitoring module's `zone_id`). Null, with a null `domain`: the stack has no record and the policy changes nothing in Route 53. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
