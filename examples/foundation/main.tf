provider "aws" {
  region = "us-east-1"

  # The modules take no tag map. Every resource inherits these, and each
  # module adds `Component` and `Name`.
  default_tags {
    tags = {
      Project     = "infra"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

# The account's GitHub Actions OIDC provider. An account has one; it is
# created once, outside this configuration. The foundation policies let the
# roles read it, never change it.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  # Literals here; in a real stack these are outputs of the modules that
  # create the state bucket and the hosted zone.
  state_bucket_arn = "arn:aws:s3:::acme-tfstate"
  hosted_zone_arn  = "arn:aws:route53:::hostedzone/Z0123456789ABCDEFGHIJ"
}

# The roles of the stack that owns the account's shared resources: the state
# bucket, the hosted zone, and every project's buckets, roles and policies,
# these two roles included.
module "ci" {
  source = "../../"

  name_root         = "acme"
  project           = "infra"
  repository        = "acme/infra"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  environment       = "production"

  plan_policies  = ["tfstate/read", "foundation/read"]
  apply_policies = ["tfstate/write", "foundation/read", "foundation/manage"]

  policy_inputs = {
    # One state object, not a prefix: this stack reads no other stack's state.
    tfstate = {
      bucket_arn = local.state_bucket_arn
      key        = "project=infra/env=prod/terraform.tfstate"
    }
    foundation = {
      state_bucket_arn = local.state_bucket_arn
      hosted_zone_arn  = local.hosted_zone_arn
    }
  }
}

output "plan_role_arn" {
  description = "For `role-to-assume` in the pull request workflow."
  value       = module.ci.plan_role_arn
}

output "apply_role_arn" {
  description = "For `role-to-assume` in the release workflow's job, which must run in the `production` environment."
  value       = module.ci.apply_role_arn
}

output "apply_policy_arns" {
  description = "The managed policies attached to the apply role, by catalog name."
  value       = module.ci.apply_policy_arns
}
