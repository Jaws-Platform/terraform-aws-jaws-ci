# monitoring/backup

Manage the monitoring node's snapshots in
[`monitoring-node`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest/submodules/monitoring-node)
(`snapshots.enabled`): the AWS Backup vault `<name_root>-<project>-snapshots`,
the backup plan of the same name and its selection `<name_root>-<project>-data`,
with what creating a vault with the default key needs, and pass the
`<name_root>-<project>-snapshots` role to `backup.amazonaws.com`. Class:
**write**.

The snapshots role and its `AWSBackupServiceRolePolicyForBackup` attachment
are created with
[`monitoring/node`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/node).
Write policies grant no reads; pair it with
[`monitoring/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/read)
on the apply role. The vault refuses to be deleted while it holds recovery
points, and this policy deletes none.

Part of the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["monitoring/backup"]`; it is not meant to be called
directly.

## How it is scoped

- **The vault by name**, `<name_root>-<project>-snapshots`.
- **Backup plans by region.** A plan's ARN holds a random ID, not its name,
  and its selections are authorized against the plan, so `ManageThePlan`
  names `backup-plan:*`: the role can create, change and delete any backup
  plan in the region, and its selections.
- **The vault's key only through AWS Backup.** The default key `aws/backup`
  has a random ID, so `UseTheVaultKeyThroughBackup` names every key in the
  region with `kms:ViaService = backup.<region>.amazonaws.com`.

## Known gaps

| Statement | Why it is `*` |
|---|---|
| `MountTheVaultStorage` (`backup-storage:MountCapsule`) | `CreateBackupVault` mounts the vault's storage, and this action has no resource-level support. |

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
| name | Name of the managed policy, for example `acme-monitoring-ci-apply-monitoring-backup`. | `string` | n/a | yes |
| name\_root | Prefix of resource names, in kebab-case. The monitoring stack names everything from `<name_root>-<project>`: roles, functions, schedules, alarms, the topic and the vault are `<name_root>-<project>` or `<name_root>-<project>-*`, parameters `/<name_root>-<project>/*`. | `string` | n/a | yes |
| project | Project name in kebab-case. Every resource ARN in the policy is built from `<name_root>-<project>`. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
