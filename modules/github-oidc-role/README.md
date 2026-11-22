# github-oidc-role

Part of [`Jaws-Platform/jaws-ci/aws`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest) · [Registry](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/github-oidc-role) · [Source](https://github.com/Jaws-Platform/terraform-aws-jaws-ci/tree/main/modules/github-oidc-role)

One IAM role that GitHub Actions assumes through OIDC. It is the building
block that [`ci-plan-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-plan-role),
[`ci-preview-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-preview-role),
[`ci-apply-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-apply-role),
[`ci-release-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-release-role)
and [`ci-task-role`](https://registry.terraform.io/modules/Jaws-Platform/jaws-ci/aws/latest/submodules/ci-task-role)
compose, so the trust-policy logic, including the immutable subject form,
exists in exactly one place. Use it directly for a role whose permissions you
write yourself.

## Trust policy

The role has a single trust statement that allows
`sts:AssumeRoleWithWebIdentity` from `oidc_provider_arn`. The statement has
two `StringEquals` conditions:

- `token.actions.githubusercontent.com:aud` is `sts.amazonaws.com`.
- `token.actions.githubusercontent.com:sub` is one of the subjects built from
  every prefix and every suffix in `subjects`.

GitHub issues `sub` in one of two shapes depending on the repository's OIDC
settings. The classic form is `repo:<owner>/<name>:...` and the immutable form
is `repo:<owner>@<owner_id>/<name>@<repository_id>:...`. The classic prefix is
always trusted. Pass `owner_id` and `repository_id` to trust the immutable
prefix as well.

| `subjects` | IDs set | Trusted `sub` values |
|---|---|---|
| `["pull_request"]` | no | `repo:owner/repo:pull_request` |
| `["pull_request"]` | yes | `repo:owner/repo:pull_request`, `repo:owner@1/repo@2:pull_request` |
| `["environment:prod"]` | yes | `repo:owner/repo:environment:prod`, `repo:owner@1/repo@2:environment:prod` |

### Renaming or transferring the repository

Both forms of `sub` carry the repository's name, and the immutable form
carries its owner's numeric ID too, so a role stops matching the moment the
repository is renamed or moved to another account. Trust the new identity
first, apply, and only then rename or transfer:

- **A rename** keeps the owner: add the new name to `repository_aliases`.
- **A transfer** changes the owner's name and ID, while `repository_id` stays
  the same: add the new `owner/repo` to `repository_aliases`, and the new
  owner's ID to `repository_alias_owner_ids`.

```hcl
repository         = "acme/guitar"
repository_aliases = ["acme-org/guitar"]
owner_id           = "12345678"  # acme
repository_id      = "123456789" # unchanged by the transfer

repository_alias_owner_ids = {
  "acme-org/guitar" = "87654321" # gh api users/acme-org --jq .id
}
```

That role trusts `repo:acme/guitar:...`, `repo:acme-org/guitar:...`,
`repo:acme@12345678/guitar@123456789:...` and
`repo:acme-org@87654321/guitar@123456789:...`. Once the move is done and no
workflow run can still carry the old identity, make the new name
`repository`, the new owner's ID `owner_id`, and remove the alias.

The statement's `Sid` defaults to `GitHubOidc`. Set `trust_statement_sid` to
the Sid an existing role already uses to adopt it without a trust-policy diff.

## Permissions

- `inline_policies` maps a suffix to a policy document object. Each entry
  becomes `aws_iam_role_policy.this["<key>"]`, named `<name>-<key>`, with the
  document passed through `jsonencode()` so the policy is known at plan time.
- `managed_policy_arns` lists managed policies. Each becomes
  `aws_iam_role_policy_attachment.this["<arn>"]`.
- `managed_policies` maps a name to a managed policy ARN. Each becomes
  `aws_iam_role_policy_attachment.keyed["<key>"]`.

These resource addresses are part of the module's contract. Callers adopting
existing roles write `moved` blocks against them.

### Managed policy ARNs must be known at plan time

Terraform needs the keys of a `for_each` before it applies, and the keys of
`aws_iam_role_policy_attachment.this` are the ARNs. Passing the `arn` of a
policy that is created in the same run fails with "for_each set includes
values derived from resource attributes that cannot be determined until
apply". Use `managed_policies` instead, whose keys are names you choose and
whose ARNs may be unknown until apply:

```hcl
managed_policies = {
  extra = aws_iam_policy.extra.arn
}
```

Or build the ARN from values that are known:

```hcl
managed_policy_arns = [
  "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.extra_policy_name}",
]
```

Inline policies do not have this limit. Only their keys must be known, and
their documents may reference values that are unknown until apply.

## Tags

The module sets `Component = <component>`. All other tags come from the
caller's provider `default_tags`. Set `name_tag` to also add a `Name` tag,
which lets a caller adopt an existing role that already carries one without a
tag change.

## Usage

```hcl
module "plan_role" {
  source  = "Jaws-Platform/jaws-ci/aws//modules/github-oidc-role"
  version = "0.3.0" # x-release-please-version

  name              = "acme-infra-ci-plan"
  description       = "terraform plan for acme/acme-infra pull requests (read-only)"
  repository        = "acme/acme-infra"
  owner_id          = "12345678"   # gh api users/acme --jq .id
  repository_id     = "1234567890" # gh api repos/acme/acme-infra --jq .id
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  subjects          = ["pull_request"]
  component         = "ci"

  managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]

  inline_policies = {
    state = {
      Version   = "2012-10-17"
      Statement = [{ Sid = "ReadOwnState", Effect = "Allow", Action = "s3:GetObject", Resource = "arn:aws:s3:::bucket/key" }]
    }
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

| Name | Version |
| ---- | ------- |
| aws | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.keyed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| component | Value of the `Component` tag on the role. | `string` | n/a | yes |
| description | IAM role description, for example `terraform plan for owner/repo pull requests (read-only)`. | `string` | n/a | yes |
| name | IAM role name. Inline policies are named `<name>-<key>`. | `string` | n/a | yes |
| oidc\_provider\_arn | ARN of the account's GitHub Actions OIDC provider (`token.actions.githubusercontent.com`). | `string` | n/a | yes |
| repository | GitHub repository whose workflows may assume the role, as `owner/repo`. | `string` | n/a | yes |
| subjects | Subject suffixes the role trusts, appended to `repo:<repository>:` (and to the immutable prefix when the IDs are set). For example `["pull_request"]`, `["environment:prod"]` or `["ref:refs/tags/v*"]`. Subjects containing `*` or `?` are matched with `StringLike`; the others with `StringEquals`. | `list(string)` | n/a | yes |
| inline\_policies | Inline policies to attach, keyed by suffix. Each value is an IAM policy document object (`{ Version = "2012-10-17", Statement = [...] }`) that becomes `aws_iam_role_policy.this[<key>]` named `<name>-<key>` with `policy = jsonencode(value)`. | `any` | `{}` | no |
| managed\_policies | Managed policies to attach, keyed by a name that is known at plan time. Each becomes `aws_iam_role_policy_attachment.keyed[<key>]`. Unlike `managed_policy_arns`, the ARNs may be unknown until apply, so policies created in the same run can be attached. | `map(string)` | `{}` | no |
| managed\_policy\_arns | ARNs of managed policies to attach. Each becomes `aws_iam_role_policy_attachment.this[<arn>]`. | `list(string)` | `[]` | no |
| max\_session\_duration | Maximum session duration in seconds for the role. | `number` | `3600` | no |
| name\_tag | Value of the `Name` tag. Left `null`, the module sets no `Name` tag and `Component` is the only tag it adds. | `string` | `null` | no |
| owner\_id | Numeric GitHub ID of the repository owner (`gh api users/<owner> --jq .id`). When set together with `repository_id`, the role also trusts GitHub's immutable subject form `repo:<owner>@<owner_id>/<name>@<repository_id>:...`. | `string` | `null` | no |
| repository\_alias\_owner\_ids | Numeric GitHub owner ID of an alias whose owner is a different account from `repository`'s, keyed by the alias, for example `{ "new-org/example" = "123456789" }`. A repository that is transferred to another account keeps its `repository_id` and gets a new owner, and GitHub's immutable subject form carries the owner's ID as well as its name, so the alias is trusted in that form only with the new owner's ID. An alias without an entry is trusted with `owner_id`, which is right for a rename. Only used when `owner_id` and `repository_id` are set. | `map(string)` | `{}` | no |
| repository\_aliases | Other names the same repository is trusted under, as `owner/repo`, for example its new name while it is being renamed. Each is trusted exactly like `repository`, with the same `repository_id` and, unless `repository_alias_owner_ids` gives it another, the same `owner_id`. Remove an alias once no workflow run can carry it. | `list(string)` | `[]` | no |
| repository\_id | Numeric GitHub ID of the repository (`gh api repos/<owner>/<repo> --jq .id`). When set together with `owner_id`, the role also trusts GitHub's immutable subject form. | `string` | `null` | no |
| trust\_statement\_sid | Sid of the single trust-policy statement. Only the trust policy JSON changes with it; set it to the Sid an existing role already uses to adopt the role without a diff. | `string` | `"GitHubOidc"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| arn | ARN of the role, for `role-to-assume` in `aws-actions/configure-aws-credentials`. |
| assume\_role\_policy | The role's trust policy as a JSON string. Exposed so composing modules can test the trust policy. |
| id | ID of the role (the same as its name). |
| inline\_policies | Map of `inline_policies` key to `{ name, policy }`, where `policy` is the JSON document attached to the role. |
| managed\_policies | Map of `managed_policies` key to the ARN attached under it. |
| managed\_policy\_arns | ARNs of the managed policies attached to the role, sorted. |
| max\_session\_duration | Maximum session duration of the role, in seconds. |
| name | Name of the role. |
| tags | Tags the module sets on the role (`Component`, and `Name` when `name_tag` is set). Excludes provider `default_tags`. |
<!-- END_TF_DOCS -->
