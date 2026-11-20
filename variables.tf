variable "name_root" {
  description = "Prefix of the role and policy names in kebab-case, usually a short name for the organisation such as `acme`. The roles are named `<name_root>-<project>-ci-plan` and `<name_root>-<project>-ci-apply`, and the policies that scope by name reach only resources named `<name_root>-<project>-*`."
  type        = string
}

variable "project" {
  description = "Project in kebab-case, for example `guitar`. It is part of both role names, which must fit IAM's 64-character limit, and the policies that scope by tag reach only resources tagged `Project = <project>`."
  type        = string
}

variable "repository" {
  description = "GitHub repository whose workflows may assume the roles, as `owner/repo`."
  type        = string
}

variable "repository_aliases" {
  description = "Other names the same repository is trusted under, as `owner/repo`, for example its new name while it is being renamed. Each is trusted exactly like `repository`. Remove an alias once no workflow run can carry it."
  type        = list(string)
  default     = []
}

variable "repository_alias_owner_ids" {
  description = "Numeric GitHub owner ID of an alias whose owner is a different account from `repository`'s, keyed by the alias, for example `{ \"new-org/example\" = \"123456789\" }`: for a repository that is being transferred to another account, whose immutable subject then carries the new owner's ID. An alias without an entry is trusted with `owner_id`."
  type        = map(string)
  default     = {}
}

variable "owner_id" {
  description = "Numeric GitHub ID of the repository owner (`gh api users/<owner> --jq .id`). Set it together with `repository_id` and both roles also trust GitHub's immutable subject form, `repo:<owner>@<owner_id>/<name>@<repository_id>:...`. Null trusts the classic form only."
  type        = string
  default     = null
}

variable "repository_id" {
  description = "Numeric GitHub ID of the repository (`gh api repos/<owner>/<repo> --jq .id`). Set it together with `owner_id`."
  type        = string
  default     = null
}

variable "oidc_provider_arn" {
  description = "ARN of the account's GitHub Actions OIDC provider, `arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com`. An account has one; this module does not create it."
  type        = string
}

variable "environment" {
  description = "GitHub environment whose jobs may assume the apply role: it trusts `repo:<repository>:environment:<environment>` and nothing else. Protect the environment with required reviewers and restrict its deployment branches."
  type        = string
  default     = "prod"
}

variable "plan_policies" {
  description = "Policies of the plan role, by catalog name, for example `[\"tfstate/read\", \"static-site/read\"]`. Any pull request in the repository can assume this role, so it accepts only `read` and `common` policies; the `ci-policies` module lists them."
  type        = set(string)
}

variable "apply_policies" {
  description = "Policies of the apply role, by catalog name, for example `[\"tfstate/write\", \"static-site/read\", \"static-site/deploy\"]`. It accepts `read`, `write` and `common` policies. Write policies grant no reads, so list the matching read policy too."
  type        = set(string)
}

variable "policy_inputs" {
  description = "Values the policies of both roles are built from, one optional section per policy family, for example `tfstate = { bucket_arn, key or prefix }` and `static_site = { bucket_arn, zone_id, record_names }`. Only the sections the requested policies need are required. The `ci-policies` module documents every section and checks the shape; an attribute it does not know is dropped silently."
  # `any`: the catalog module owns the type, so a new policy family does not
  # change this module.
  type    = any
  default = {}
}
