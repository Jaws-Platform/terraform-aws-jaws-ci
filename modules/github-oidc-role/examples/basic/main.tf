locals {
  # Modules take no tag map. Every resource inherits these through the
  # provider's default_tags, and each module adds `Component` (and `Name`).
  tags = {
    Organization = "acme"
    Project      = "infra"
    Environment  = "prod"
    Repository   = "acme/acme-infra"
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

# A read-only plan role for pull requests, trusted in both subject forms.
module "plan_role" {
  source = "../../"

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
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ReadOwnState"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:GetObjectVersion"]
          Resource = "arn:aws:s3:::acme-tfstate/project=infra/env=prod/infra-prod.tfstate"
        },
      ]
    }
  }
}

output "plan_role_arn" {
  value = module.plan_role.arn
}
