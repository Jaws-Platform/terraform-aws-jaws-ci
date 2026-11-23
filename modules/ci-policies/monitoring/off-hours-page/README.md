# monitoring/off-hours-page

Manage the off-hours page of the monitoring node of
[`jaws-monitoring`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest)
([`monitoring-node`](https://registry.terraform.io/modules/Jaws-Platform/jaws-monitoring/aws/latest/submodules/monitoring-node)):
the ACM certificate for `domain` (in us-east-1, DNS-validated), the CloudFront
distribution and function `<name_root>-<project>-off-hours-page` that serve the
page, and the certificate's validation record. Class: **write**.

Write policies grant no reads; pair it with
[`monitoring/read`](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/ci-policies/monitoring/read),
which holds the reads of the certificate, distribution and function for both
roles. The schedule and the role policy the page also needs are covered by
`monitoring/node`.

Part of the [`ci-policies`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-policies) catalog. Request it from a CI role module
with `policies = ["monitoring/off-hours-page"]` and
`policy_inputs = { monitoring = { zone_id, domain } }`; it is not meant to be
called directly.

## How it is scoped

- **Tags.** The caller's provider tags every resource `Project = <project>`.
  Creating a certificate, distribution or function needs
  `aws:RequestTag/Project`; changing or deleting one needs
  `aws:ResourceTag/Project`.
- **The certificate by name and method.** `acm:RequestCertificate` is limited to
  `acm:ValidationMethod = DNS` and, with `ForAllValues:StringEquals`, to
  `acm:DomainNames` of `domain` alone, lowercased and without a trailing dot.
- **The function by name.** `function/<name_root>-<project>-off-hours-page`
  only. Distributions and certificates have random IDs, so they are scoped by
  the `Project` tag.
- **Route 53 by record.** `ChangeResourceRecordSets` is limited to the hosted
  zone, to CNAME records, and to names matching `_*.<domain>`, which is where
  ACM's validation record lives.

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
| domain | The node's domain (the monitoring module's `domain`), for example `grafana.example.com`. The off-hours page's certificate is requested for exactly this name, and its validation record is `_<token>.<domain>`. | `string` | n/a | yes |
| name | Name of the managed policy, for example `acme-monitoring-ci-apply-monitoring-off-hours-page`. | `string` | n/a | yes |
| name\_root | Prefix of resource names, in kebab-case. The monitoring stack names everything from `<name_root>-<project>`: roles, functions, schedules, alarms, the topic and the vault are `<name_root>-<project>` or `<name_root>-<project>-*`, parameters `/<name_root>-<project>/*`. | `string` | n/a | yes |
| project | Project name in kebab-case. Every resource ARN in the policy is built from `<name_root>-<project>`. | `string` | n/a | yes |
| zone\_id | Route 53 hosted zone of the node's domain (the monitoring module's `zone_id`). The certificate's validation record is changed in this zone only. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the managed policy. |
| name | Name of the managed policy. |
| policy | The policy document as a JSON string. |
<!-- END_TF_DOCS -->
