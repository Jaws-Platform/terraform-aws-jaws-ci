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

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "chess_bot_task" {
  source = "../../"

  name_root         = "acme"
  project           = "chess-bot"
  repository        = "acme/chess-bot"
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn

  policies = ["task/launch"]
  policy_inputs = {
    task = { instance_types = ["c8a.xlarge", "c8a.2xlarge"] }
  }
}

output "role_arn" {
  value = module.chess_bot_task.role_arn
}
