locals {
  # Modules take no tag map. Every resource inherits these through the
  # provider's default_tags, and each module adds `Component` (and `Name`).
  tags = {
    Organization = "acme"
    Project      = "guitar"
    Environment  = "prod"
    Repository   = "acme/guitar"
    ManagedBy    = "terraform"
    Owner        = "platform-team"
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = local.tags
  }
}

module "ci_apply" {
  source = "../../"

  name_root         = "acme"
  project           = "guitar"
  repository        = "acme/guitar"
  owner_id          = "12345678"  # gh api users/acme --jq .id
  repository_id     = "123456789" # gh api repos/acme/guitar --jq .id
  oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  environment       = "prod"

  policies = ["tfstate/write", "static-site/read", "static-site/deploy"]

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
        "dev.guitar.example.com",
        "*.preview.guitar.example.com",
      ]
    }
  }
}

output "role_arn" {
  value = module.ci_apply.role_arn
}

output "policy_arns" {
  value = module.ci_apply.policy_arns
}
