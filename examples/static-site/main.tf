provider "aws" {
  region = "us-east-1"

  # The modules take no tag map. Every resource inherits these, and each
  # module adds `Component` and `Name`. The roles belong to the stack that
  # creates them, here the account's platform stack, not to the project
  # whose workflows assume them.
  default_tags {
    tags = {
      Project     = "platform"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# The account's GitHub Actions OIDC provider. An account has one; it is
# created once, outside this configuration.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  repository    = "acme/guitar"
  owner_id      = "12345678"  # gh api users/acme --jq .id
  repository_id = "123456789" # gh api repos/acme/guitar --jq .id

  # What the policies are scoped to. Literals here; in a real stack these are
  # outputs of the modules that create the state bucket, the site bucket and
  # the hosted zone.
  policy_inputs = {
    tfstate = {
      bucket_arn = "arn:aws:s3:::acme-tfstate"
      prefix     = "project=guitar/"
    }
    static_site = {
      bucket_arn = "arn:aws:s3:::acme-guitar"
      zone_id    = "Z0123456789ABCDEFGHIJ"
      record_names = [
        "guitar.example.com",
        "*.preview.guitar.example.com",
      ]
    }
  }
}

# The plan role, for pull requests, and the apply role, for jobs in the
# `prod` environment.
module "ci" {
  source = "../../"

  name_root         = "acme"
  project           = "guitar"
  repository        = local.repository
  owner_id          = local.owner_id
  repository_id     = local.repository_id
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  plan_policies  = ["tfstate/read", "static-site/read"]
  apply_policies = ["tfstate/write", "static-site/read", "static-site/deploy"]
  policy_inputs  = local.policy_inputs
}

# A third role publishes pull request previews. Like the plan role it can be
# assumed from any pull request, so it can write nothing but `previews/` in
# the site bucket.
module "ci_preview" {
  source = "../../modules/ci-preview-role"

  name_root         = "acme"
  project           = "guitar"
  repository        = local.repository
  owner_id          = local.owner_id
  repository_id     = local.repository_id
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  policies      = ["static-site/previews"]
  policy_inputs = local.policy_inputs
}

output "plan_role_arn" {
  description = "For `role-to-assume` in the pull request workflow's plan job."
  value       = module.ci.plan_role_arn
}

output "preview_role_arn" {
  description = "For `role-to-assume` in the pull request workflow's preview job."
  value       = module.ci_preview.role_arn
}

output "apply_role_arn" {
  description = "For `role-to-assume` in the release workflow's job, which must run in the `prod` environment."
  value       = module.ci.apply_role_arn
}
