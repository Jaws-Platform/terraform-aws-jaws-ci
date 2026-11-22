# task/records

Write the records a task launcher keeps about each run: `s3:PutObject` on
`arn:aws:s3:::<bucket>/<prefix>/*`, and nothing else. A launcher such as the
Jaws CLI writes one JSON object per task-run event under the project's prefix,
for example
`raw/provider=acme/source=task-runs/project=<project>/date=YYYY-MM-DD/<run>.<task>.<event>.json`.
Class: **task**, requested by
[`ci-task-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-task-role).

- **Put only.** The writer puts each record once, with `If-None-Match: *`; a
  conditional put needs no permission beyond `s3:PutObject`.
- **One prefix of one bucket.** `prefix` has no leading or trailing slash and
  no `*` or `?`, so the grant cannot reach past `<prefix>/`.
- **No reads.** It cannot get, list or delete objects, its own records
  included, or read or change the bucket's configuration.

For a bucket in the role's own account with SSE-S3 encryption, the default,
nothing else is needed. A bucket in another account must also allow the put in
its bucket policy, and a bucket whose default encryption is a customer-managed
KMS key also needs `kms:GenerateDataKey` on that key; this policy grants
neither.

Part of the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["task/records"]` and
`policy_inputs = { task = { records = { bucket = "...", prefix = "..." } } }`.

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

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| bucket | Name (not ARN) of the bucket the task-run records are written to, for example `acme-billing-123456789012`. | `string` | n/a | yes |
| name | Name of the managed policy, for example `acme-chess-bot-ci-task-task-records`. | `string` | n/a | yes |
| prefix | Key prefix of the project's records, without a leading or trailing slash, for example `raw/provider=acme/source=task-runs/project=chess-bot`. The policy covers every object under `<prefix>/`. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
